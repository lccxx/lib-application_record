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
    return { error: nil, t_count: t_count, data: r } if args[:info]
    return { error: nil, data: r }
  end

  def to_hash(c={ })
    self.attributes
  end
end
