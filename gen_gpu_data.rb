#!/usr/local/ruby/bin/ruby
require 'mysql'
require 'wikk_sql'
require 'wikk_json'
require 'wikk_configuration'
require 'date'
require 'fileutils'


DATAFILE=__dir__ + '/../data/gpu_data.json'
WWW_DATAFILE='/var/www/html2/data/gpu_data.json'
MYSQL_CONF=__dir__ + '/../etc/db.json'

class Date
  def to_j
    self.to_s.to_j
  end
end

def generate_data_file(file:, rows: )
  File.open(file, "w+") do |fd|
    fd.puts rows.to_j
  end
end

def row_status(row:)
  if row['launched_at'] == '' && row['terminated_at'] == ''
    'available'
  else
    row['launched_at'] = Date.parse(row['launched_at'])
    row['terminated_at'] = Date.parse(row['terminated_at'])
    #puts "#{row['launched_at']} #{row['terminated_at']}"
    #Then we allocated this GPU at some point
    if row['launched_at'] <= @today && row['terminated_at'] >= @today
      'allocated'
    elsif row['terminated_at'] < @today
      'past'
    else
      'future'
    end
  end
end

def color(status:)
  if status == 'reserved' 
    'red' 
  elsif status == 'past'
    '#7FDBFF'
  elsif status == 'future'
    'yellow'
  elsif status == 'available'
    'white'
  else
    'Gradient(#ffffdd:green)'
  end
end

EPOCH = '2017-07-04'
END_OF_TIME = '9999-12-31'

def gantt_dates(row:)
  soy = Date.parse("#{@today.year}-01-01")
  eoy = Date.parse("#{@today.year}-12-31")
  #Exit, if not in use.
  return [ soy,  soy, 0, 0, 100] if row['status'] == 'available'

  start_date = row['start_date'] == '' ? Date.parse(EPOCH) : Date.parse(row['start_date'])
  end_date = row['end_date'] == '' ? Date.parse(END_OF_TIME) : Date.parse(row['end_date'])

  graph_start_date = row['launched_at'].year < @today.year ? soy : (row['launched_at'].year > @today.year ? eoy : row['launched_at'] )
  graph_end_date = row['terminated_at'].year > @today.year  ? eoy : (row['terminated_at'].year < @today.year ? soy : row['terminated_at'])
  
  #Use the number of days in the project to set a fake percentage finished, so the used point matches today.
  days = (graph_end_date - graph_start_date).to_i 
  #if(graph_end_date != graph_start_date)
  if(graph_end_date <= soy || graph_start_date > eoy)
    days = 0
  else
    days += 1
  end
  complete_days = (@today - graph_start_date).to_i + 1
  actual_days = (graph_end_date - graph_start_date).to_i + 1
  complete = if complete_days <= 0
               0 #in the future
             elsif  complete_days >= actual_days
               100 #Ended
             else 
               (complete_days * 100.0)/actual_days
             end
             
  return [start_date, end_date, graph_start_date.yday, days, complete]
end

def load_data_from_db(sql:)
  rows = {}
  query = "SELECT concat(hypervisor, '-', pci_id) as rowkey, hypervisor, gpu_type, instance_uuid, instance_name, project_name,  project_uuid as project_id, start_date, end_date, email, pci_id, ip , instance_launched_at as launched_at, instance_terminated_at as terminated_at from gpu_nodes left join ip2project_gpu_nodes on gpu_nodes.id = gpu_node_id left join ip2project on ip2project_id = ip2project.id where active = 1 order by gpu_type, hypervisor"
  sql.each_hash(query) do |row|
    row.each do |k,v|
      row[k] = '' if v.nil?
    end
    row['label'] = ''
    row['y_label'] = "#{row['hypervisor']}-#{row['gpu_type']}"
    row['status'] = row_status(row: row)
    row['color'] = color(status: row['status'])
    row['start_date'], row['end_date'], row['start'], row['duration'], row['complete'] = gantt_dates(row: row)
    rows[row['rowkey']] ||= []
    rows[row['rowkey']] << row
  end
  return rows
end

def main
  @today = Date.today()

  mysql_conf =  WIKK::Configuration.new(MYSQL_CONF)
  WIKK::SQL::connect(mysql_conf) do |sql_fd|
    @rows = load_data_from_db(sql: sql_fd)
  end

  rows_arr = @rows.collect { |k,v| v }
  generate_data_file(file: DATAFILE, rows: rows_arr)

  FileUtils.mv(DATAFILE, WWW_DATAFILE)
  
main

