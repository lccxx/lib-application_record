require 'bson'

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  before_create { self.id = BSON::ObjectId.new.to_s.to_i(16).to_s(36) if id.nil? }

  def self.qry(args)
    r = self.all

    if args[:where]
      args[:where].map { |k, v|
        if v.start_with?('~')
          args[:like] = args[:like] || { }
          args[:like][k] = args[:where].delete(k).sub('~', '')
        end
      }
      r = r.where(args[:where])
    end
    if args[:like]
      args[:like].map { |k, v| r = r.where("`#{k.to_s.gsub('`', '')}` LIKE ?", v.gsub('*', '%')) }
    end
    if args[:send]
      args[:send].map { |k, v| r = r.where(id: self.send(*(([ k ] << v).flatten))) }
    end
    r = r.or(self.where(args[:or])) if args[:or]
    t_count = r.count if args[:info]

    args[:limit] = 999 if args[:limit].blank?
    r = r.limit(args[:limit])
    if args[:order]
      args[:order][:id] = :desc if args[:order][:id].nil? && !args[:no_id]
      r = r.order(args[:order])
    else
      r = r.order(id: :desc)
    end

    if args[:contain].blank?
      args[:contain] = { }
    else
      args[:contain] = args[:contain].gsub(/ /, '').split(",").map { |item| [ item, 1 ] }.to_h
    end
    r = r.map { |e| e.to_hash(args[:contain]) } if not args[:selfish]
    if args[:xls]
      return xls(r)
    end
    return { error: nil, t_count: t_count, data: r } if args[:info]
    return { error: nil, data: r }
  end

  def self.xlsx(argv)
    argv[:xls] = 1
    download_file = "#{self.class.table_name}-#{Time.now.strftime("%Y.%m.%d·%H.%M.%S")}.xlsx"
    yield(self.class.qry(argv).to_stream.read, type: "application/xlsx", filename: download_file)
  end

  def self.xls(data)
    Axlsx::Package.new { |p| p.workbook.add_worksheet { |sheet|
      if data.is_a?(Enumerable)
        sheet.add_row data.first.keys if data.first
        data.each { |row|
          sheet.add_row { |line|
            row.map { |k, v|
              next line.add_cell v.in_time_zone("Asia/Shanghai").to_s if k.to_s.ends_with?("_at")
              line.add_cell v.to_s
            }
          }
        }
      end
    } }
  end

  def to_hash(c={ })
    self.attributes
  end
end
