require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { should have_many(:events) }
    it { should have_many(:orders) }
    it { should have_many(:bookmarks) }
  end

  describe "validations" do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email) }
    it { should validate_presence_of(:name) }
  end
end
