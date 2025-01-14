require "rails_helper"

RSpec.describe CheckAnswersSummaryListCardComponent, type: :component do
  context "when given a set of questions" do
    let(:user) { FactoryBot.build(:user) }
    let(:case_log) { FactoryBot.build(:case_log, :completed, age2: 99) }
    let(:subsection_id) { "household_characteristics" }
    let(:subsection) { case_log.form.get_subsection(subsection_id) }
    let(:questions) { subsection.applicable_questions(case_log) }

    it "renders a summary list card for the answers to those questions" do
      result = render_inline(described_class.new(questions:, case_log:, user:))
      expect(result).to have_content(questions.first.answer_label(case_log))
    end

    it "applicable questions doesn't return questions that are hidden in check answers" do
      summary_list = described_class.new(questions:, case_log:, user:)
      expect(summary_list.applicable_questions.map(&:id).include?("retirement_value_check")).to eq(false)
    end

    it "has the correct answer label for a question" do
      summary_list = described_class.new(questions:, case_log:, user:)
      sex1_question = questions[2]
      expect(summary_list.get_answer_label(sex1_question)).to eq("Female")
    end
  end
end
