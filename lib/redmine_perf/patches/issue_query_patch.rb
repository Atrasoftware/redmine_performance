require_dependency 'issue_query'

module  RedminePerf
  module  Patches
    module IssueQueryPatch
      def self.included(base)
        base.extend(ClassMethods)

        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method_chain :issues, :perf
          class<< self
          end

          scope :visible, lambda {|*args|
            user = args.shift || User.current
            base = Project.allowed_to_condition(user, :view_issues, *args)
            scope = joins("LEFT OUTER JOIN #{Project.table_name} ON #{table_name}.project_id = #{Project.table_name}.id").
                where("#{table_name}.project_id IS NULL OR (#{base})")

            if user.admin?
              scope.where("#{table_name}.visibility <> ? OR #{table_name}.user_id = ?", Query::VISIBILITY_PRIVATE, user.id)
            elsif user.memberships.count > 0
              scope.where("#{table_name}.visibility = ?" +
                              " OR (#{table_name}.visibility = ? AND #{table_name}.id IN (" +
                              "SELECT DISTINCT q.id FROM #{table_name} q" +
                              " INNER JOIN #{table_name_prefix}queries_roles#{table_name_suffix} qr on qr.query_id = q.id" +
                              " INNER JOIN #{MemberRole.table_name} mr ON mr.role_id = qr.role_id" +
                              " INNER JOIN #{Member.table_name} m ON m.id = mr.member_id AND m.user_id = ?" +
                              " WHERE q.project_id IS NULL OR q.project_id = m.project_id))" +
                              " OR #{table_name}.user_id = ?",
                          Query::VISIBILITY_PUBLIC, Query::VISIBILITY_ROLES, user.id, user.id)
            elsif user.logged?
              scope.where("#{table_name}.visibility = ? OR #{table_name}.user_id = ?", Query::VISIBILITY_PUBLIC, user.id)
            else
              scope.where("#{table_name}.visibility = ?", Query::VISIBILITY_PUBLIC)
            end
          }
        end
      end
    end
    module InstanceMethods
      def issues_with_perf(options={})
        order_option = [group_by_sort_order, options[:order]].flatten.reject(&:blank?)

        v = joins_for_order_statement(order_option.join(','))
        scope = Issue.visible.
            where(statement).
            includes(([:status, :project] + (options[:include] || [])).uniq).
            references(([:status, :project] + (options[:include] || [])).uniq).
            where(options[:conditions]).
            order(order_option).
            includes(v).
            references(v).
            limit(options[:limit]).
            offset(options[:offset])

        scope = scope.preload(:custom_values)
        if has_column?(:author)
          scope = scope.preload(:author)
        end

        issues = scope.to_a

        if has_column?(:spent_hours)
          Issue.load_visible_spent_hours(issues)
        end
        if has_column?(:total_spent_hours)
          Issue.load_visible_total_spent_hours(issues)
        end
        if has_column?(:relations)
          Issue.load_visible_relations(issues)
        end
        issues
      rescue ::ActiveRecord::StatementInvalid => e
        raise StatementInvalid.new(e.message)
      end
    end

    module ClassMethods
    end

  end
end
