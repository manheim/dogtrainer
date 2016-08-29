# define top level of module in the right file
module DogTrainer
end

gem_libs_dir = "#{File.dirname File.absolute_path(__FILE__)}/dogtrainer"
Dir.glob("#{gem_libs_dir}/*.rb") { |file| require file }
