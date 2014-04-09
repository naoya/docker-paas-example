#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "git"
require "erb"

class Repository
  attr_accessor :git
  attr_reader :git_repo, :vm_addr, :basedir, :docker_user

  def self.create(args)
    repo = self.new(args)
    repo.git = Git.init(repo.basedir + "/" + repo.reponame)
    repo.git.config('receive.denyCurrentBranch', 'ignore')

    Dir.chdir(repo.git.repo.path + "/hooks") do
      erb = ERB.new(DATA.read)
      File.open('post-update', 'w') do |f|
        f.puts(erb.result(repo.create_binding))
        f.chmod(0755)
      end
    end

    return repo
  end

  def initialize(args)
    @git_repo    = args[:git_repo]
    @vm_addr     = args[:vm_addr]
    @basedir     = args[:basedir]
    @docker_user = args[:docker_user]
  end

  def create_binding
    binding
  end

  def serial
    @serial ||= `ls #{@basedir} | wc -l`
  end

  def reponame
    sprintf("docker-paas-%04d", serial)
  end

  def port
    sprintf("5%04d", serial)
  end

  def dir
    git.dir
  end

  def url
    "#{git_repo}:#{git.dir}"
  end
end

repo = Repository.create(
  git_repo: 'naoya@192.168.56.1',
  vm_addr:  '192.168.56.100',
  basedir:  "/Users/naoya/work/docker-paas",
  docker_user: "naoya",
)
puts repo.url

__END__
#!/bin/bash
set -eo pipefail
# set -x

export DOCKER_HOST=tcp://127.0.0.1:4243
export PATH=/usr/local/bin:$PATH

if [ -f is_running ];then
  echo "-----> Killing current container"
  job=`cat is_running`
  docker kill $job
fi

echo "-----> Fetching application source"

job=$(docker run -i -a stdin <%= docker_user %>/docker-paas /bin/bash -c \
    "git clone <%= git_repo %>:<%= dir %> /root/<%= reponame %>")
test $(docker wait $job) -eq 0
docker commit $job <%= docker_user %>/<%= reponame %> > /dev/null

echo "-----> Building new container ..."

job=$(docker run -i -a stdin -v /var/cache/docker-paas/<%= reponame %>/buildpacks:/var/cache/buildpacks <%= docker_user %>/<%= reponame %> /bin/bash -c \
    "for buildpack in /var/lib/buildpacks/*; do \$buildpack/bin/detect /root/<%= reponame %> && selected_buildpack=\$buildpack && break; done;
     if [ -n \$selected_buildpack ]; then echo \"\$selected_buildpack detected\"; else exit 1; fi;
     CURL_TIMEOUT=360 \$selected_buildpack/bin/compile /root/<%= reponame %> /var/cache/buildpacks &&
     \$selected_buildpack/bin/release /root/<%= reponame %> > /root/<%= reponame %>/.release")
test $(docker wait $job) -eq 0
docker commit $job <%= docker_user %>/<%= reponame %> > /dev/null

echo "-----> Starting Application"

job=$(docker run -i -t -d -p <%= port %>:8080 <%= docker_user %>/<%= reponame %> /bin/bash -c \
    "export HOME=/root/<%= reponame %> &&
     cd \$HOME &&
     for file in .profile.d/*; do source \$file; done &&
     hash -r &&
     /var/lib/buildpacks/exec-release.rb .release")

echo $job > is_running
echo "URL: http://<%= vm_addr %>:<%= port %>/"
echo "http://<%= vm_addr %>:<%= port %>/" | pbcopy
