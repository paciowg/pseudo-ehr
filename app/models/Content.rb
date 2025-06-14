# Content Model
class Content
  attr_reader :id, :title, :type, :data

  def initialize(title:, type:, data:, url:)
    @id = SecureRandom.hex(16)
    @title = title
    @type = type
    @data = data
    @url = url

    self.class.all << self
  end

  class << self
    def all
      @all ||= []
    end
  end
end
