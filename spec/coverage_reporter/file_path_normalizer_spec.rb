# frozen_string_literal: true

require "spec_helper"

RSpec.describe CoverageReporter::FilePathNormalizer do
  subject(:normalizer) { described_class.new }

  describe ".call" do
    it "delegates to instance method" do
      normalizer = instance_double(described_class)
      allow(described_class).to receive(:new).and_return(normalizer)
      allow(normalizer).to receive(:call).with("test.rb").and_return("normalized.rb")

      result = described_class.call("test.rb")

      expect(result).to eq("normalized.rb")
    end
  end

  describe "#call" do
    context "when file_path is nil" do
      it "returns nil" do
        expect(normalizer.call(nil)).to be_nil
      end
    end

    context "when file_path is empty" do
      it "returns nil" do
        expect(normalizer.call("")).to be_nil
      end
    end

    context "when file_path starts with current working directory" do
      it "removes the project root prefix" do
        current_dir = Dir.pwd
        file_path = "#{current_dir}/lib/example.rb"

        result = normalizer.call(file_path)

        expect(result).to eq("lib/example.rb")
      end

      it "removes leading slash after removing project root" do
        current_dir = Dir.pwd
        file_path = "#{current_dir}/spec/example_spec.rb"

        result = normalizer.call(file_path)

        expect(result).to eq("spec/example_spec.rb")
      end

      it "handles nested paths correctly" do
        current_dir = Dir.pwd
        file_path = "#{current_dir}/lib/coverage_reporter/example.rb"

        result = normalizer.call(file_path)

        expect(result).to eq("lib/coverage_reporter/example.rb")
      end
    end

    context "when file_path is absolute but doesn't start with current working directory" do
      it "extracts relative path from /lib/ pattern" do
        file_path = "/some/absolute/path/lib/example.rb"

        result = normalizer.call(file_path)

        expect(result).to eq("lib/example.rb")
      end

      it "extracts relative path from /spec/ pattern" do
        file_path = "/some/absolute/path/spec/example_spec.rb"

        result = normalizer.call(file_path)

        expect(result).to eq("spec/example_spec.rb")
      end

      it "handles nested paths in /lib/ pattern" do
        file_path = "/some/absolute/path/lib/coverage_reporter/example.rb"

        result = normalizer.call(file_path)

        expect(result).to eq("lib/coverage_reporter/example.rb")
      end

      it "handles nested paths in /spec/ pattern" do
        file_path = "/some/absolute/path/spec/coverage_reporter/example_spec.rb"

        result = normalizer.call(file_path)

        expect(result).to eq("spec/coverage_reporter/example_spec.rb")
      end

      it "uses the last occurrence of the pattern" do
        file_path = "/some/lib/path/lib/example.rb"

        result = normalizer.call(file_path)

        expect(result).to eq("lib/example.rb")
      end

      it "returns original path for directories not in current project" do
        file_path = "/some/absolute/path/app/models/user.rb"

        result = normalizer.call(file_path)

        expect(result).to eq("/some/absolute/path/app/models/user.rb")
      end

      it "works with actual project directories (lib and spec)" do
        # Test with lib directory (exists in this project)
        lib_file_path = "/some/absolute/path/lib/coverage_reporter/example.rb"
        result = normalizer.call(lib_file_path)
        expect(result).to eq("lib/coverage_reporter/example.rb")

        # Test with spec directory (exists in this project)
        spec_file_path = "/some/absolute/path/spec/coverage_reporter/example_spec.rb"
        result = normalizer.call(spec_file_path)
        expect(result).to eq("spec/coverage_reporter/example_spec.rb")
      end

      it "returns original path if no recognized source directory pattern found" do
        file_path = "/some/absolute/path/unknown/directory/file.rb"

        result = normalizer.call(file_path)

        expect(result).to eq("/some/absolute/path/unknown/directory/file.rb")
      end
    end

    context "when file_path is relative" do
      it "returns the path as-is" do
        file_path = "lib/example.rb"

        result = normalizer.call(file_path)

        expect(result).to eq("lib/example.rb")
      end

      it "handles nested relative paths" do
        file_path = "lib/coverage_reporter/example.rb"

        result = normalizer.call(file_path)

        expect(result).to eq("lib/coverage_reporter/example.rb")
      end

      it "handles relative paths outside current directory" do
        file_path = "../sibling/file.rb"

        result = normalizer.call(file_path)

        expect(result).to eq("../sibling/file.rb")
      end
    end

    context "edge cases" do
      it "handles file_path that is exactly the current working directory" do
        current_dir = Dir.pwd

        result = normalizer.call(current_dir)

        expect(result).to eq("")
      end

      it "handles file_path that ends with /lib/" do
        file_path = "/some/path/lib/"

        result = normalizer.call(file_path)

        expect(result).to eq("lib/")
      end

      it "handles file_path that ends with /spec/" do
        file_path = "/some/path/spec/"

        result = normalizer.call(file_path)

        expect(result).to eq("spec/")
      end

      it "handles file_path with multiple /lib/ patterns" do
        file_path = "/some/lib/path/lib/example.rb"

        result = normalizer.call(file_path)

        expect(result).to eq("lib/example.rb")
      end

      it "handles file_path with multiple /spec/ patterns" do
        file_path = "/some/spec/path/spec/example_spec.rb"

        result = normalizer.call(file_path)

        expect(result).to eq("spec/example_spec.rb")
      end
    end
  end
end
