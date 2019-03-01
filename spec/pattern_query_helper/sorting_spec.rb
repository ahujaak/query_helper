require "spec_helper"

RSpec.describe PatternQueryHelper::Sorting do

  describe "parse_sorting_params" do
    it "parses params into sorting sql string" do
      sort_string = PatternQueryHelper::Sorting.parse_sorting_params("name:desc")
      expect(sort_string).to eq("name desc")
    end

    it "lowercase if asked for" do
      sort_string = PatternQueryHelper::Sorting.parse_sorting_params("name:desc:lowercase")
      expect(sort_string).to eq("lower(name) desc")
    end
  end

  describe "sort_active_record_query" do
    it "sorts active record query" do
      sort_string = PatternQueryHelper::Sorting.parse_sorting_params("name:desc")
      parents = PatternQueryHelper::Sorting.sort_active_record_query(Parent.all, sort_string)

      previous_parent_name = "zzzzzzzzzz"
      parents.each do |parent|
        expect(parent.name <=> previous_parent_name).to eq(-1)
        previous_parent_name = parent.name
      end
    end
  end
end
