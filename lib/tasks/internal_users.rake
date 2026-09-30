# frozen_string_literal: true

namespace :redmine do
  namespace :internal_users do
    desc <<~DESC
      Refreshes the internal status of users from the registered directory.
      By default, only demotes internal users no longer in the directory.
      SEED=1 also promotes users found in the directory (initial run).
      FORCE=1 allows demoting more than 10% of the internal users.
    DESC
    task :sync => :environment do
      begin
        sync = InternalUserSync.new(seed: ENV['SEED'] == '1', force: ENV['FORCE'] == '1').run
      rescue RedmineInternalUsers::DirectoryError, InternalUserSync::TooManyDemotions => e
        abort "Aborted, nothing changed: #{e.message}"
      end

      log_path = Rails.root.join('log', "internal_users-#{Time.current.strftime('%Y%m%d-%H%M%S')}.log")
      File.open(log_path, 'w') do |file|
        { 'promoted' => sync.promoted, 'demoted' => sync.demoted }.each do |label, ids|
          User.where(id: ids).order(:login).pluck(:login).each { |login| file.puts "#{label} #{login}" }
        end
      end
      puts "checked: #{sync.checked.size}, promoted: #{sync.promoted.size}, demoted: #{sync.demoted.size} (#{log_path})"
    end
  end
end
