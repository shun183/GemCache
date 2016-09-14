module RailsSqlViews
  module ConnectionAdapters
    module Mysql2Adapter
      def self.included(base)

        base.class_eval do
          alias_method :original_tables_method, :tables
          alias_method :tables, :base_tables
        end

        if base.private_method_defined?(:supports_views?) || base.protected_method_defined?(:supports_views?)
          base.send(:public, :supports_views?)
        end
      end

      # Returns true as this adapter supports views.
      def supports_views?
        true
      end

      def base_tables(name = nil, database = nil, like = nil) #:nodoc:
        tables_of_type(name, database, like, "BASE TABLE")
      end
      alias nonview_tables base_tables
      
      def views(name = nil, database = nil, like = nil) #:nodoc:
        tables_of_type(name, database, like, "VIEW")
      end

      def tables_with_views_included(name = nil, database = nil, like = nil)
        nonview_tables(name, database, like) + views(name, database, like)
      end
      
      def structure_dump
        structure = ""
        base_tables.each do |table|
          structure += select_one("SHOW CREATE TABLE #{quote_table_name(table)}")["Create Table"] + ";\n\n"
        end

        views.each do |view|
          structure += select_one("SHOW CREATE VIEW #{quote_table_name(view)}")["Create View"] + ";\n\n"
        end

        return structure
      end

      # Get the view select statement for the specified table.
      def view_select_statement(view, name=nil)
        begin
          row = execute("SHOW CREATE VIEW #{view}", name).each do |row|
            return convert_statement(row[1]) if row[0] == view
          end
        rescue ActiveRecord::StatementInvalid => e
          raise "No view called #{view} found"
        end
      end
      
      private
      def convert_statement(s)
        s.gsub!(/.* AS (select .*)/, '\1')
      end

      def tables_of_type(name, database, like, table_type)
        sql = "SHOW FULL TABLES "
        sql << "IN #{quote_table_name(database)} " if database
        sql << "LIKE #{quote(like)} " if like
        execute_and_free(sql, 'SCHEMA') do |result|
          result.select { |f| f.last == table_type }.map(&:first)
        end
      end
    end
  end
end
