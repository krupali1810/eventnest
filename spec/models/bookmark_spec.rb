require "rails_helper"

RSpec.describe Bookmark, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:event) }
  end

  describe "validations" do
    subject(:bookmark) { create(:bookmark) }

    it { should validate_uniqueness_of(:event_id).scoped_to(:user_id) }
  end
end
