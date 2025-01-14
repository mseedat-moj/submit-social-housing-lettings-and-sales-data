require "rails_helper"

RSpec.describe Imports::CaseLogsImportService do
  subject(:case_log_service) { described_class.new(storage_service, logger) }

  let(:storage_service) { instance_double(Storage::S3Service) }
  let(:logger) { instance_double(ActiveSupport::Logger) }

  let(:real_2021_2022_form) { Form.new("config/forms/2021_2022.json", "2021_2022") }
  let(:real_2022_2023_form) { Form.new("config/forms/2022_2023.json", "2022_2023") }
  let(:fixture_directory) { "spec/fixtures/imports/logs" }

  let(:organisation) { FactoryBot.create(:organisation, old_visible_id: "1", provider_type: "PRP") }
  let(:scheme1) { FactoryBot.create(:scheme, old_visible_id: 123, owning_organisation: organisation) }
  let(:scheme2) { FactoryBot.create(:scheme, old_visible_id: 456, owning_organisation: organisation) }

  def open_file(directory, filename)
    File.open("#{directory}/#{filename}.xml")
  end

  before do
    WebMock.stub_request(:get, /api.postcodes.io\/postcodes\/LS166FT/)
           .to_return(status: 200, body: '{"status":200,"result":{"admin_district":"Westminster","codes":{"admin_district":"E08000035"}}}', headers: {})

    allow(Organisation).to receive(:find_by).and_return(nil)
    allow(Organisation).to receive(:find_by).with(old_visible_id: organisation.old_visible_id.to_i).and_return(organisation)

    # Created by users
    FactoryBot.create(:user, old_user_id: "c3061a2e6ea0b702e6f6210d5c52d2a92612d2aa", organisation:)
    FactoryBot.create(:user, old_user_id: "e29c492473446dca4d50224f2bb7cf965a261d6f", organisation:)

    # Location setup
    FactoryBot.create(:location, old_visible_id: 10, postcode: "LS166FT", scheme_id: scheme1.id, mobility_type: "W")
    FactoryBot.create(:location, scheme_id: scheme1.id)
    FactoryBot.create(:location, old_visible_id: 10, postcode: "LS166FT", scheme_id: scheme2.id, mobility_type: "W")

    # Stub the form handler to use the real form
    allow(FormHandler.instance).to receive(:get_form).with("2021_2022").and_return(real_2021_2022_form)
    allow(FormHandler.instance).to receive(:get_form).with("2022_2023").and_return(real_2022_2023_form)
  end

  context "when importing case logs" do
    let(:remote_folder) { "case_logs" }
    let(:case_log_id) { "0ead17cb-1668-442d-898c-0d52879ff592" }
    let(:case_log_id2) { "166fc004-392e-47a8-acb8-1c018734882b" }
    let(:case_log_id3) { "00d2343e-d5fa-4c89-8400-ec3854b0f2b4" }
    let(:case_log_id4) { "0b4a68df-30cc-474a-93c0-a56ce8fdad3b" }

    before do
      # Stub the S3 file listing and download
      allow(storage_service).to receive(:list_files)
                                  .and_return(%W[#{remote_folder}/#{case_log_id}.xml #{remote_folder}/#{case_log_id2}.xml #{remote_folder}/#{case_log_id3}.xml #{remote_folder}/#{case_log_id4}.xml])
      allow(storage_service).to receive(:get_file_io)
                                  .with("#{remote_folder}/#{case_log_id}.xml")
                                  .and_return(open_file(fixture_directory, case_log_id), open_file(fixture_directory, case_log_id))
      allow(storage_service).to receive(:get_file_io)
                                  .with("#{remote_folder}/#{case_log_id2}.xml")
                                  .and_return(open_file(fixture_directory, case_log_id2), open_file(fixture_directory, case_log_id2))
      allow(storage_service).to receive(:get_file_io)
                                  .with("#{remote_folder}/#{case_log_id3}.xml")
                                  .and_return(open_file(fixture_directory, case_log_id3), open_file(fixture_directory, case_log_id3))
      allow(storage_service).to receive(:get_file_io)
                                  .with("#{remote_folder}/#{case_log_id4}.xml")
                                  .and_return(open_file(fixture_directory, case_log_id4), open_file(fixture_directory, case_log_id4))
    end

    it "successfully create all case logs" do
      expect(logger).not_to receive(:error)
      expect(logger).not_to receive(:warn)
      expect(logger).not_to receive(:info)
      expect { case_log_service.create_logs(remote_folder) }
        .to change(CaseLog, :count).by(4)
    end

    it "only updates existing case logs" do
      expect(logger).not_to receive(:error)
      expect(logger).not_to receive(:warn)
      expect(logger).to receive(:info).with(/Updating case log/).exactly(4).times
      expect { 2.times { case_log_service.create_logs(remote_folder) } }
        .to change(CaseLog, :count).by(4)
    end

    context "when there are status discrepancies" do
      let(:case_log_id5) { "893ufj2s-lq77-42m4-rty6-ej09gh585uy1" }
      let(:case_log_id6) { "5ybz29dj-l33t-k1l0-hj86-n4k4ma77xkcd" }
      let(:case_log_file) { open_file(fixture_directory, case_log_id5) }
      let(:case_log_xml) { Nokogiri::XML(case_log_file) }

      before do
        allow(storage_service).to receive(:get_file_io)
          .with("#{remote_folder}/#{case_log_id5}.xml")
          .and_return(open_file(fixture_directory, case_log_id5), open_file(fixture_directory, case_log_id5))
        allow(storage_service).to receive(:get_file_io)
          .with("#{remote_folder}/#{case_log_id6}.xml")
          .and_return(open_file(fixture_directory, case_log_id6), open_file(fixture_directory, case_log_id6))
      end

      it "the logger logs a warning with the case log's old id/filename" do
        expect(logger).to receive(:warn).with(/is not completed/).once
        expect(logger).to receive(:warn).with(/Case log with old id:#{case_log_id5} is incomplete but status should be complete/).once

        case_log_service.send(:create_log, case_log_xml)
      end

      it "on completion the ids of all logs with status discrepancies are logged in a warning" do
        allow(storage_service).to receive(:list_files)
                                  .and_return(%W[#{remote_folder}/#{case_log_id5}.xml #{remote_folder}/#{case_log_id6}.xml])
        expect(logger).to receive(:warn).with(/is not completed/).twice
        expect(logger).to receive(:warn).with(/is incomplete but status should be complete/).twice
        expect(logger).to receive(:warn).with(/The following case logs had status discrepancies: \[893ufj2s-lq77-42m4-rty6-ej09gh585uy1, 5ybz29dj-l33t-k1l0-hj86-n4k4ma77xkcd\]/)

        case_log_service.create_logs(remote_folder)
      end
    end
  end

  context "when importing a specific log" do
    let(:case_log_id) { "0ead17cb-1668-442d-898c-0d52879ff592" }
    let(:case_log_file) { open_file(fixture_directory, case_log_id) }
    let(:case_log_xml) { Nokogiri::XML(case_log_file) }

    context "and the void date is after the start date" do
      before { case_log_xml.at_xpath("//xmlns:VYEAR").content = 2023 }

      it "does not import the voiddate" do
        expect(logger).to receive(:warn).with(/is not completed/)
        expect(logger).to receive(:warn).with(/Case log with old id:#{case_log_id} is incomplete but status should be complete/)

        case_log_service.send(:create_log, case_log_xml)

        case_log = CaseLog.where(old_id: case_log_id).first
        expect(case_log&.voiddate).to be_nil
      end
    end

    context "and the organisation legacy ID does not exist" do
      before { case_log_xml.at_xpath("//xmlns:OWNINGORGID").content = 99_999 }

      it "raises an exception" do
        expect { case_log_service.send(:create_log, case_log_xml) }
          .to raise_error(RuntimeError, "Organisation not found with legacy ID 99999")
      end
    end

    context "and a person is under 16" do
      before { case_log_xml.at_xpath("//xmlns:P2Age").content = 14 }

      context "when the economic status is set to refuse" do
        before { case_log_xml.at_xpath("//xmlns:P2Eco").content = "10) Refused" }

        it "sets the economic status to child under 16" do
          # The update is done when calculating derived variables
          expect(logger).to receive(:warn).with(/Differences found when saving log/)
          case_log_service.send(:create_log, case_log_xml)

          case_log = CaseLog.where(old_id: case_log_id).first
          expect(case_log&.ecstat2).to be(9)
        end
      end

      context "when the relationship to lead tenant is set to refuse" do
        before { case_log_xml.at_xpath("//xmlns:P2Rel").content = "Refused" }

        it "sets the relationship to lead tenant to child" do
          case_log_service.send(:create_log, case_log_xml)

          case_log = CaseLog.where(old_id: case_log_id).first
          expect(case_log&.relat2).to eq("C")
        end
      end
    end

    context "and this is an internal transfer from a non social housing" do
      before do
        case_log_xml.at_xpath("//xmlns:Q11").content = "9 Residential care home"
        case_log_xml.at_xpath("//xmlns:Q16").content = "1 Internal Transfer"
      end

      it "intercepts the relevant validation error" do
        expect(logger).to receive(:warn).with(/Removing internal transfer referral since previous tenancy is a non social housing/)
        expect { case_log_service.send(:create_log, case_log_xml) }
          .not_to raise_error
      end

      it "clears out the referral answer" do
        allow(logger).to receive(:warn)

        case_log_service.send(:create_log, case_log_xml)
        case_log = CaseLog.find_by(old_id: case_log_id)

        expect(case_log).not_to be_nil
        expect(case_log.referral).to be_nil
      end

      context "and this is an internal transfer from a previous fixed term tenancy" do
        before do
          case_log_xml.at_xpath("//xmlns:Q11").content = "30 Fixed term Local Authority General Needs tenancy"
          case_log_xml.at_xpath("//xmlns:Q16").content = "1 Internal Transfer"
        end

        it "intercepts the relevant validation error" do
          expect(logger).to receive(:warn).with(/Removing internal transfer referral since previous tenancy is fixed terms or lifetime/)
          expect { case_log_service.send(:create_log, case_log_xml) }
            .not_to raise_error
        end

        it "clears out the referral answer" do
          allow(logger).to receive(:warn)

          case_log_service.send(:create_log, case_log_xml)
          case_log = CaseLog.find_by(old_id: case_log_id)

          expect(case_log).not_to be_nil
          expect(case_log.referral).to be_nil
        end
      end
    end

    context "and the net income soft validation is triggered (net_income_value_check)" do
      before do
        case_log_xml.at_xpath("//xmlns:Q8a").content = "1 Weekly"
        case_log_xml.at_xpath("//xmlns:Q8Money").content = 890.00
      end

      it "completes the log" do
        case_log_service.send(:create_log, case_log_xml)
        case_log = CaseLog.find_by(old_id: case_log_id)
        expect(case_log.status).to eq("completed")
      end
    end

    context "and the rent soft validation is triggered (rent_value_check)" do
      before do
        case_log_xml.at_xpath("//xmlns:Q18ai").content = 200.00
        case_log_xml.at_xpath("//xmlns:Q18av").content = 232.02
        case_log_xml.at_xpath("//xmlns:Q17").content = "1 Weekly for 52 weeks"
        LaRentRange.create!(
          start_year: 2021,
          la: "E08000035",
          beds: 2,
          lettype: 1,
          soft_max: 900,
          hard_max: 1500,
          soft_min: 500,
          hard_min: 100,
        )
      end

      it "completes the log" do
        case_log_service.send(:create_log, case_log_xml)
        case_log = CaseLog.find_by(old_id: case_log_id)
        expect(case_log.status).to eq("completed")
      end
    end

    context "and the retirement soft validation is triggered (retirement_value_check)" do
      before do
        case_log_xml.at_xpath("//xmlns:P1Age").content = 68
        case_log_xml.at_xpath("//xmlns:P1Eco").content = "6) Not Seeking Work"
      end

      it "completes the log" do
        case_log_service.send(:create_log, case_log_xml)
        case_log = CaseLog.find_by(old_id: case_log_id)
        expect(case_log.status).to eq("completed")
      end
    end

    context "and this is a supported housing log with multiple locations under a scheme" do
      let(:case_log_id) { "0b4a68df-30cc-474a-93c0-a56ce8fdad3b" }

      it "sets the scheme and location values" do
        expect(logger).not_to receive(:warn)
        case_log_service.send(:create_log, case_log_xml)
        case_log = CaseLog.find_by(old_id: case_log_id)

        expect(case_log.scheme_id).not_to be_nil
        expect(case_log.location_id).not_to be_nil
        expect(case_log.status).to eq("completed")
      end
    end

    context "and this is a supported housing log with a single location under a scheme" do
      let(:case_log_id) { "0b4a68df-30cc-474a-93c0-a56ce8fdad3b" }

      before { case_log_xml.at_xpath("//xmlns:_1cmangroupcode").content = scheme2.old_visible_id }

      it "sets the scheme and location values" do
        expect(logger).not_to receive(:warn)
        case_log_service.send(:create_log, case_log_xml)
        case_log = CaseLog.find_by(old_id: case_log_id)

        expect(case_log.scheme_id).not_to be_nil
        expect(case_log.location_id).not_to be_nil
        expect(case_log.status).to eq("completed")
      end
    end
  end
end
