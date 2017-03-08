class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  before_create { self.id = ("%7s%25s" % [
      (Time.now.to_f * 10).to_i.to_s(36),
      SecureRandom.uuid.gsub('-', '').to_i(16).to_s(36) ]).gsub(' ', '0') }

  def self.qry(args)
    r = self.all

    r = r.where(args[:where]) if args[:where]
    if args[:send]
      args[:send].map { |k, v|
        r = r.where(id: self.send(*(([ k ] << v).flatten)))
      }
    end
    r = r.or(self.where(args[:or])) if args[:or]
    t_count = r.count if args[:info]

    args[:limit] = 999 if args[:limit].blank?
    r = r.limit(args[:limit])
    if args[:order]
      args[:order][:id] = :desc if args[:order][:id].nil?
      r = r.order(args[:order])
    else
      r = r.order(id: :desc)
    end

    if args[:contain].blank?
      args[:contain] = { }
    else
      args[:contain] = args[:contain].split(",").map { |item| [ item, 1 ] }.to_h
    end
    r = r.map { |e| e.to_hash(args[:contain]) } if not args[:selfish]
    return { error: nil, t_count: t_count, data: r } if args[:info]
    return { error: nil, data: r }
  end

  def to_hash(c={ })
    self.attributes
  end
end
