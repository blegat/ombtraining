require "spec_helper"

describe Solvedproblem do

  before { @sp = FactoryGirl.build(:solvedproblem) }

  subject { @sp }

  it { should respond_to(:problem) }
  it { should respond_to(:user) }

  it { should be_valid }

  # Problem
  describe "when problem is not present" do
    before { @sp.problem = nil }
    it { should_not be_valid }
  end

  # User
  describe "when user is not present" do
    before { @sp.user = nil }
    it { should_not be_valid }
  end

end
