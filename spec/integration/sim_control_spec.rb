require 'tmpdir'

describe RunLoop::SimControl do

  subject(:sim_control) { RunLoop::SimControl.new }

  # flickering on Travis CI
  unless Resources.shared.travis_ci?
    describe '#quit_sim and #launch_sim' do
      before(:each) { RunLoop::SimControl.terminate_all_sims }

      it "with Xcode #{Resources.shared.current_xcode_version}" do
        sim_control.launch_sim({:hide_after => false})
        expect(sim_control.sim_is_running?).to be == true

        sim_control.quit_sim
        expect(sim_control.sim_is_running?).to be == false
      end

      xcode_installs = Resources.shared.alt_xcode_install_paths
      unless xcode_installs.empty?
        describe 'regression' do
          xcode_installs.each do |developer_dir|
            it "#{developer_dir}" do
              Resources.shared.with_developer_dir(developer_dir) do
                local_sim_control = RunLoop::SimControl.new
                local_sim_control.launch_sim({:hide_after => true})
                expect(local_sim_control.sim_is_running?).to be == true

                local_sim_control.quit_sim
                expect(local_sim_control.sim_is_running?).to be == false
              end
            end
          end
        end
      end
    end
  end

  describe '#relaunch_sim' do

    before(:each) { RunLoop::SimControl.terminate_all_sims }

    it "with Xcode #{Resources.shared.current_xcode_version}" do
      sim_control.relaunch_sim({:hide_after => true})
      expect(sim_control.sim_is_running?).to be == true
    end

    xcode_installs = Resources.shared.alt_xcode_install_paths
    unless xcode_installs.empty?
      describe 'regression' do
        xcode_installs.each do |developer_dir|
          it "#{developer_dir}" do
            Resources.shared.with_developer_dir(developer_dir) do
              local_sim_control = RunLoop::SimControl.new
              local_sim_control.relaunch_sim({:hide_after => true})
              expect(local_sim_control.sim_is_running?).to be == true
            end
          end
        end
      end
    end
  end

  describe '#sim_app_support_dir' do
    before(:each) {  RunLoop::SimControl.terminate_all_sims }
    it "with Xcode #{Resources.shared.current_xcode_version} returns a path that exists" do
      sim_control.relaunch_sim({:hide_after => true})
      path = sim_control.instance_eval { sim_app_support_dir }
      expect(File.exist?(path)).to be == true
    end

    describe 'regression' do
      xcode_installs = Resources.shared.alt_xcode_install_paths
      if xcode_installs.empty?
        it 'not alternative versions of Xcode found' do
          expect(true).to be == true
        end
      else
        xcode_installs.each do |developer_dir|
          it "returns a valid path for #{developer_dir}" do
            RunLoop::SimControl.terminate_all_sims
            Resources.shared.with_developer_dir(developer_dir) do
              local_sim_control = RunLoop::SimControl.new
              local_sim_control.relaunch_sim({:hide_after => true})
              path = local_sim_control.instance_eval { sim_app_support_dir }
              expect(File.exist?(path)).to be == true
            end
          end
        end
      end
    end
  end

  unless Resources.shared.travis_ci?
    describe '#reset_sim_content_and_settings' do

      before(:each) do
        RunLoop::SimControl.terminate_all_sims
        @opts = {:hide_after => true}
      end

      it "with Xcode #{Resources.shared.current_xcode_version}" do
        sim_control.reset_sim_content_and_settings(@opts)
        actual = sim_control.instance_eval { existing_sim_sdk_or_device_data_dirs }
        expect(actual).to be_a Array
        expect(actual.count).to be >= 1
      end

      # Xcode >= 6 only method
      if RunLoop::XCTools.new.xcode_version_gte_6?
        describe "with Xcode #{Resources.shared.current_xcode_version}" do
          it "can reset the content and settings on a single simulator" do
            udid = sim_control.instance_eval { sim_details :udid }.keys.sample
            options = @opts.merge({:sim_udid => udid})
            sim_control.reset_sim_content_and_settings(options)
            containers_dir = Resources.shared.core_simulator_device_containers_dir(udid)
            expect(File.exist? containers_dir).to be == false
          end
        end
      end
    end
  end

  describe '#enable_accessibility_on_sims' do
    before(:each) {
      RunLoop::SimControl.terminate_all_sims
    }

    it "with Xcode #{Resources.shared.current_xcode_version}" do
      expect(sim_control.enable_accessibility_on_sims).to be == true
    end
  end

  describe '#simctl_reset' do
    before(:each) {
      RunLoop::SimControl.terminate_all_sims
    }

    it 'raises an error if on Xcode < 6' do
      local_sim_control = RunLoop::SimControl.new
      expect(local_sim_control).to receive(:xcode_version_gte_6?).and_return(false)
      expect { local_sim_control.instance_eval { simctl_reset } }.to raise_error RuntimeError
    end

    if RunLoop::XCTools.new.xcode_version_gte_6?
      it 'resets the _all_ simulators when sim_udid is nil' do
        expect(sim_control.send(:simctl_reset)).to be == true
        sim_details = sim_control.send(:sim_details, :udid)
        sim_details.each_key { |udid|
          containers_dir = Resources.shared.core_simulator_device_containers_dir(udid)
          expect(File.exist? containers_dir).to be == false
        }
      end

      describe 'when sim_udid arg is not nil' do
        it 'raises an error when the sim_udid is invalid' do
          expect { sim_control.instance_eval { simctl_reset('unknown udid') } }.to raise_error RuntimeError
        end
        it 'resets the simulator with corresponding udid' do
          sim_details = sim_control.instance_eval { sim_details(:udid) }
          udid = sim_details.keys.sample
          expect( sim_control.instance_eval { simctl_reset(udid) } ).to be == true
          containers_dir = Resources.shared.core_simulator_device_containers_dir(udid)
          expect(File.exist? containers_dir).to be == false
        end
      end
    end
  end

  describe '#sims_details' do
    describe 'raises an error when called' do
      it 'on XCode < 6' do
        local_sim_control = RunLoop::SimControl.new
        expect(local_sim_control).to receive(:xcode_version_gte_6?).and_return(false)
        expect { local_sim_control.instance_eval { sim_details(:any_arg) } }.to raise_error RuntimeError
      end

      if RunLoop::XCTools.new.xcode_version_gte_6?
        it 'is passed an invalid argument' do
          expect { sim_control.instance_eval { sim_details(:invalid_arg) } }.to raise_error ArgumentError
        end
      end
    end

    if RunLoop::XCTools.new.xcode_version_gte_6?
      describe 'returns a hash with the primary key' do
        it ':udid' do
          actual = sim_control.instance_eval { sim_details :udid }
          expect(actual).to be_a Hash
          expect(actual.count).to be > 1
        end

        it ':launch_name' do
          actual = sim_control.instance_eval { sim_details :launch_name }
          expect(actual).to be_a Hash
          expect(actual.count).to be > 1
        end
      end
    end
  end
end
