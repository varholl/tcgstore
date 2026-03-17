namespace :db do
  desc "Download production DB from Fly.io, scrub emails, and replace local development DB"
  task download_production: :environment do
    app_name = "varhollgaragesale"
    remote_path = "/data/production.sqlite3"
    tmp_path = Rails.root.join("tmp", "production_download.sqlite3")
    dev_db_path = Rails.root.join("db", "development.sqlite3")

    puts "Downloading production database from Fly.io..."
    unless system("fly sftp get #{remote_path} #{tmp_path} -a #{app_name}")
      abort "Failed to download database. Make sure you're authenticated with `fly auth login`."
    end

    puts "Scrubbing user emails..."
    preserved_emails = %w[matias.laino@gmail.com matias.laino@passare.com]

    require "sqlite3"
    db = SQLite3::Database.new(tmp_path.to_s)
    placeholders = preserved_emails.map { "?" }.join(", ")
    db.execute(
      "UPDATE users SET email = 'user' || id || '@example.com' WHERE email NOT IN (#{placeholders})",
      preserved_emails
    )
    scrubbed = db.changes
    db.close

    puts "Scrubbed #{scrubbed} user email(s)."
    puts "Replacing development database..."
    FileUtils.cp(tmp_path, dev_db_path)
    FileUtils.rm(tmp_path)

    puts "Done! Development database replaced with scrubbed production data."
  end
end
