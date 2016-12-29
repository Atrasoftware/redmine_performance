require_dependency 'user'

module  RedminePerf
  module  Patches
    module UserPatch
      def self.included(base)
        base.extend(ClassMethods)

        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method_chain :projects_by_role, :perf
          alias_method_chain :reload, :memberships
          def allowed_to?(action, context, options={}, &block)
            if context && context.is_a?(Project)
              return false unless context.allows_to?(action)
              # Admin users are authorized for anything else
              return true if admin?

              roles = roles_for_project(context)
              return false unless roles
              roles.any? {|role|
                (context.is_public? || role.member?) &&
                    role.allowed_to?(action) &&
                    (block_given? ? yield(role, self) : true)
              }
            elsif context && context.is_a?(Array)
              if context.empty?
                false
              else
                # Authorize if user is authorized on every element of the array
                context.map {|project| allowed_to?(action, project, options, &block)}.reduce(:&)
              end
            elsif context
              raise ArgumentError.new("#allowed_to? context argument must be a Project, an Array of projects or nil")
            elsif options[:global]
              # Admin users are always authorized
              return true if admin?

              # authorize if user has at least one role that has this permission
              # rls = memberships.collect {|m| m.roles}.flatten.uniq
              # rls << (self.logged? ? Role.non_member : Role.anonymous)
              # rls.any? {|role|
              rls = user_roles.to_a
              rls << builtin_role
              rls.any? {|role|
                role.allowed_to?(action) &&
                    (block_given? ? yield(role, self) : true)
              }
            else
              false
            end
          end

        end
      end
    end
    module ClassMethods
    end

    module InstanceMethods
      def user_roles
        @roles ||= Role.joins(members: :project).where(["#{Project.table_name}.status <> ?", Project::STATUS_ARCHIVED]).where(Member.arel_table[:user_id].eq(id)).uniq
      end

      def reload_with_memberships(*args)
        @roles = nil
        @memberships = nil
        @user_statement_role = {}
        reload_without_memberships(*args)
      end

      def memberships
        @memberships ||= begin
          super
        end
      end

      def user_statement_role(permission)
        @user_statement_role ||= {}
        return @user_statement_role[permission] if @user_statement_role[permission]
        @user_statement_role[permission] = begin
          @user_statement_role[permission] = {}
          self.projects_by_role.each do |role, project_ids|
            if role.allowed_to?(permission) && project_ids.any?
              @user_statement_role[permission][role] = "#{Project.table_name}.id IN (#{project_ids.join(',')})"
            end
          end
          @user_statement_role[permission]
        end
      end


      def projects_by_role_with_perf
        return @projects_by_role if @projects_by_role

        hash = Hash.new([])

        group_class = anonymous? ? GroupAnonymous : GroupNonMember
        members = Member.joins(:project, :principal).
            where("#{Project.table_name}.status <> 9").
            where("#{Member.table_name}.user_id = ? OR (#{Project.table_name}.is_public = ? AND #{Principal.table_name}.type = ?)", self.id, true, group_class.name).
            preload(:roles).
            to_a

        members.reject! {|member| member.user_id != id && project_ids.include?(member.project_id)}
        members.each do |member|
          if member.project_id
            member.roles.each do |role|
              hash[role] = [] unless hash.key?(role)
              hash[role] << member.project_id
            end
          end
        end

        # hash.each do |role, projects|
        #   projects.uniq!
        # end

        @projects_by_role = hash
      end
    end

  end
end
