require_dependency 'user'

module  RedminePerf
  module  Patches
    module MyHelperPatch
      def self.included(base)
        base.extend(ClassMethods)

        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method_chain :render_news_block, :perf
          alias_method_chain :render_calendar_block, :perf

        end
      end
    end
    module ClassMethods
    end

    module InstanceMethods
      def render_news_block_with_perf(block, settings)
        news = News.visible.
            where(:project_id => User.current.projects.pluck(:id)).
            limit(10).
            includes(:project, :author).
            references(:project, :author).
            order("#{News.table_name}.created_on DESC").
            to_a

        render :partial => 'my/blocks/news', :locals => {:block => block, :news => news}
      end

      def render_calendar_block_with_perf(block, settings)
        calendar = Redmine::Helpers::Calendar.new(User.current.today, current_language, :week)
        calendar.events = Issue.visible.
            where(:project_id => User.current.projects.pluck(:id)).
            where("(start_date>=? and start_date<=?) or (due_date>=? and due_date<=?)", calendar.startdt, calendar.enddt, calendar.startdt, calendar.enddt).
            includes(:project, :tracker, :priority, :assigned_to).
            references(:project, :tracker, :priority, :assigned_to).
            to_a

        render :partial => 'my/blocks/calendar', :locals => {:calendar => calendar, :block => block}
      end
    end

  end
end
