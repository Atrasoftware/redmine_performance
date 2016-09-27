require_dependency 'project'

module  RedminePerf
  module  Patches
    module ProjectPatch
      def self.included(base)
        base.extend(ClassMethods)

        base.send(:include, InstanceMethods)
        base.class_eval do

          class<< self
            alias_method_chain :allowed_to_condition, :perf
          end
        end
      end

    end
    module ClassMethods
      def allowed_to_condition_with_perf(user, permission, options={})
        perm = Redmine::AccessControl.permission(permission)
        base_statement = (perm && perm.read? ? "#{Project.table_name}.status <> #{Project::STATUS_ARCHIVED}" : "#{Project.table_name}.status = #{Project::STATUS_ACTIVE}")
        if perm && perm.project_module
          # If the permission belongs to a project module, make sure the module is enabled
          base_statement << " AND EXISTS (SELECT 1 AS one FROM #{EnabledModule.table_name} em WHERE em.project_id = #{Project.table_name}.id AND em.name='#{perm.project_module}')"
          # project_ids_with_module_enabled = EnabledModule.where(name: perm.project_module).pluck(:project_id)
          # if project_ids_with_module_enabled.present?
          #   base_statement << " AND #{Project.table_name}.id IN (#{project_ids_with_module_enabled.join ','})"
          # else
          #   base_statement << " AND 1=0"
          # end
        end
        if project = options[:project]
          project_statement = project.project_condition(options[:with_subprojects])
          base_statement = "(#{project_statement}) AND (#{base_statement})"
        end

        if user.admin?
          base_statement
        else
          statement_by_role = {}
          unless options[:member]
            role = user.builtin_role
            if role.allowed_to?(permission)
              s = "#{Project.table_name}.is_public = #{connection.quoted_true}"
              if user.id
                s = "(#{s} AND #{Project.table_name}.id NOT IN (SELECT project_id FROM #{Member.table_name} WHERE user_id = #{user.id}))"
              end
              statement_by_role[role] = s
            end
          end
          statement_by_role.merge!(user.user_statement_role(permission))
          # user.projects_by_role.each do |role, project_ids|
          #   if role.allowed_to?(permission) && project_ids.any?
          #     statement_by_role[role] = "#{Project.table_name}.id IN (#{project_ids.join(',')})"
          #   end
          # end
          if statement_by_role.empty?
            "1=0"
          else
            if block_given?
              statement_by_role.each do |role, statement|
                if s = yield(role, user)
                  statement_by_role[role] = "(#{statement} AND (#{s}))"
                end
              end
            end
            "((#{base_statement}) AND (#{statement_by_role.values.join(' OR ')}))"
          end
        end
      end


    end

    module InstanceMethods

    end

  end
end
