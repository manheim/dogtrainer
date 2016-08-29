guard :bundler do
  watch('dogtrainer.gemspec')
end

guard :rubocop do
  watch(/.+\.rb$/)
  watch(%r{(?:.+\/)?\.rubocop\.yml$}) { |m| File.dirname(m[0]) }
end

guard :rspec, cmd: 'bundle exec rspec' do
  watch('spec/spec_helper.rb') { 'spec' }
  watch(%r{^spec/.+_spec\.rb})
  watch(%r{^spec/(.+)/.+_spec\.rb})
  watch(%r{^lib\/dogtrainer/(.+)\.rb$}) { |m| "spec/unit/#{m[1]}_spec.rb" }
end

guard 'yard', port: '8808' do
  watch(/README\.md/)
end
