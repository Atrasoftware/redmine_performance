Redmine::Plugin.register :redmine_performance do
  name 'Redmine Performance plugin'
  author 'Bilel KEDIDI'
  description 'This plugin perform redmine queries'
  version '0.0.2'
end

Rails.application.config.to_prepare do
  Project.send(:include, RedminePerf::Patches::ProjectPatch)
  # Principal.send(:include, RedminePerf::Patches::PrincipalPatch)
  User.send(:include, RedminePerf::Patches::UserPatch)
  MyHelper.send(:include, RedminePerf::Patches::MyHelperPatch)
  # IssueQuery.send(:include, RedminePerf::Patches::IssueQueryPatch)
  # CustomField.send(:include, RedminePerf::Patches::CustomFieldPatch)
  News.send(:include, RedminePerf::Patches::NewsPatch)
  # Redmine::Search::Fetcher.send(:include, RedminePerf::Patches::FetchPatch)
end