class Submission < ActiveRecord::Base
  attr_accessible :content, :status
  belongs_to :user
  belongs_to :problem

  has_many :corrections

  validates :user_id, presence: true
  validates :problem_id, presence: true
  validates :content, presence: true, length: { maximum: 8000 }
  validates :status, presence: true, inclusion: { in: [0, 1, 2] }
  # 0: pas corrigé
  # 1: corrigé
  # 2: résolu

  def correct?
    status == 2
  end
  def icon
    case status
    when 0
      'icon-question-sign'
    when 1
      'icon-remove-sign'
    when 2
      'icon-ok-sign'
    end

  end
end