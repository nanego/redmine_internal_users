class AddInternalStatusToUsers < ActiveRecord::Migration[6.1]
  COLUMNS = {
    # Computed from the directory
    :internal => [:boolean, { :default => false, :null => false }],
    # Set by an administrator, nil meaning automatic
    :internal_forced => [:boolean, {}],
    # Address verified by the identity provider, from which internal was computed
    :internal_mail => [:string, {}],
    :internal_checked_at => [:datetime, {}]
  }.freeze

  # The columns may already exist when they were created by redmine_restricted_public 1.0
  def up
    COLUMNS.each do |name, (type, options)|
      add_column :users, name, type, **options unless column_exists?(:users, name)
    end
  end

  def down
    COLUMNS.each_key { |name| remove_column :users, name if column_exists?(:users, name) }
  end
end
