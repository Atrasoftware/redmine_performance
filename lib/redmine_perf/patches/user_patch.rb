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

        end
      end
    end
    module ClassMethods
    end

    module InstanceMethods
      def reload_with_memberships(*args)
        @memberships = nil
        reload_without_memberships(*args)
      end

      def memberships
        @memberships ||= begin
          super
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

        hash.each do |role, projects|
          projects.uniq!
        end

        @projects_by_role = hash
      end
    end

  end
end
