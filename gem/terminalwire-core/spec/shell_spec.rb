require "spec_helper"

RSpec.describe Terminalwire::Shells::All do
  subject { described_class }
  describe ".find_by_shell_path" do
    context "'/bin/bash'" do
      it "finds bash" do
        expect(subject.find_by_shell_path("/bin/bash").name).to eq "bash"
      end
    end
  end
  it "has shells" do
    expect(subject.names).to include "bash", "zsh", "fish"
  end
  it "has login_files" do
    expect(subject.login_files).to include "~/.bash_profile", "~/.zprofile"
  end
  it "has interactive_files" do
    expect(subject.interactive_files).to include "~/.bashrc", "~/.zshrc"
  end
  it "has logout_files" do
    expect(subject.logout_files).to include "~/.zlogout"
  end
end
