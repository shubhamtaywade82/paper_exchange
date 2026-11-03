# frozen_string_literal: true

namespace :clients do
  desc "Generate both TypeScript and Ruby API clients from OpenAPI spec"
  task generate: [ "generate:ruby", "generate:ts" ]

  namespace :generate do
    desc "Generate Ruby Contractful client"
    task ruby: :environment do
      require "contractful/contract/openapi_import"
      spec_path = Rails.root.join("public/api-docs/openapi.yaml").to_s
      out_dir = Rails.root.join("clients/ruby")
      FileUtils.mkdir_p(out_dir)

      code = Contractful::Contract::OpenAPIImport.to_ruby(
        spec_path,
        class_name: "PaperExchange::Client"
      )
      code = "require \"contractful\"\n\n#{code}" unless code.include?("require \"contractful\"")
      File.write(out_dir.join("paper_exchange_client.rb"), code)
      puts "Generated Ruby client at #{out_dir.join('paper_exchange_client.rb')}"
    end

    desc "Generate TypeScript Contractful client"
    task ts: :environment do
      spec_path = Rails.root.join("public/api-docs/openapi.yaml").to_s
      out_dir = Rails.root.join("clients/ts").to_s
      FileUtils.mkdir_p(out_dir)

      cmd = "npx contractful-gen --spec #{spec_path} --out #{out_dir}"
      system(cmd, exception: true)
      puts "Generated TypeScript client in #{out_dir}"
    end
  end
end
