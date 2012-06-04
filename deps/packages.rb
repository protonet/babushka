dep 'curl.bin'

dep 'gettext.lib'

dep 'nodejs.src', :version do
  version.default!('0.6.13')
  source "http://nodejs.org/dist/node-v#{version}.tar.gz"
  provides "node ~> #{version}"
end

dep 'sudo' do
  requires {
    on :osx, 'sudo.external'
    otherwise 'sudo.bin'
  }
end

dep 'sudo.external' do
  expects 'sudo'
  otherwise {
    log_error "Your system seems to be missing sudo."
  }
end

dep 'sudo.bin'
