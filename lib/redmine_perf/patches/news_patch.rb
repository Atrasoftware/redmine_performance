require_dependency 'news'

module  RedminePerf
  module  Patches
    module NewsPatch
      def self.included(base)
        base.extend(ClassMethods)

        base.send(:include, InstanceMethods)
        base.class_eval d
        class<< self
          alias_method_chain :latest, :perf
        end
      end
    end

    module ClassMethods
      def latest_with_perf(user = User.current, count = 5)
        visible(user).includes(:author).order("#{News.table_name}.created_on DESC").limit(count).to_a
      end
    end

    module InstanceMethods

    end

  end
end
