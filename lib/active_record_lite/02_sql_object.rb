require_relative 'db_connection'
require_relative '01_mass_object'
require 'active_support/inflector'

class MassObject

  def self.parse_all(results)
    results.map do |result|
      self.new(result)
    end
  end

end

class SQLObject < MassObject
  def self.columns
    if @columns.nil?
      @columns = DBConnection.execute2("SELECT * FROM #{table_name} LIMIT 0")
      @columns = @columns.first.map(&:to_sym)
      @columns.each do |col|
        define_method(col) do
          self.attributes[col]
        end
        define_method("#{col}=") do |val|
          self.attributes[col] = val
        end
      end
      @columns
    else
      @columns
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    if self == Human
      'humans'
    else
      table_name = ActiveSupport::Inflector.pluralize(self.to_s)
      ActiveSupport::Inflector.underscore(table_name)
    end
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
    SELECT
      #{self.table_name}.*
    FROM
      #{self.table_name}
    SQL
    self.parse_all(results)
  end

  def self.find(id)
    results = DBConnection.execute(<<-SQL, id)
    SELECT
      #{self.table_name}.*
    FROM
      #{self.table_name}
    WHERE
      #{self.table_name}.id = ?
    LIMIT 1
    SQL
    self.parse_all(results).first
  end

  def attributes
    @attributes ||= {}
  end

  def insert
    col_names = self.class.columns.join(",")
    question_marks = (['?'] * self.class.columns.count ).join(',')
    DBConnection.execute(<<-SQL, *attribute_values)
    INSERT INTO
      #{self.class.table_name} (#{col_names})
    VALUES
      (#{question_marks})
    SQL
    new_row_id = DBConnection.last_insert_row_id
    attributes[:id] = new_row_id
  end

  def initialize(params = {}) # params is a signle hash
    columns = self.class.columns
    params.each do |attr_name, value|
      attr_name = attr_name.to_sym
      raise "unknown attribute '#{attr_name}'" unless columns.include?(attr_name)
      self.send("#{attr_name}=", value)
    end
  end

  def save
    attributes[:id].nil? ? insert : update
  end

  def update
    set_line = attributes.each_key.map { |key| "#{key} = ?" }.join(",")
    DBConnection.execute(<<-SQL, *attribute_values, attribute_values[0])
    UPDATE
    #{self.class.table_name}
    SET
    #{set_line}
    WHERE
    id = ?
    SQL
  end

  def attribute_values
    result = []
    self.class.columns.each do |attr_name|
      result << attributes[attr_name]
    end
    result
  end
end
