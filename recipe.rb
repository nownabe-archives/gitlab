include_recipe "nownabe_centos7_base"

# Swap

execute "create swap file" do
  command "touch /swap"
  notifies :run, "execute[change mode]", :immediately
  notifies :run, "execute[dd swap file]", :immediately
  notifies :run, "execute[make swap]", :immediately
  notifies :run, "execute[add mount point]", :immediately
  notifies :run, "execute[swapon]", :immediately
  not_if "test -f /swap"
end

execute "change mode" do
  command "chmod 600 /swap"
  action :nothing
end

execute "dd swap file" do
  command "dd if=/dev/zero of=/swap bs=1M count=1024"
  action :nothing
end

execute "make swap" do
  command "mkswap /swap"
  action :nothing
end

execute "add mount point" do
  command "echo '/swap swap swap defaults 0 0' >> /etc/fstab"
  not_if "grep -q '/swap' /etc/fstab"
end

execute "swapon" do
  command "swapon -a"
  not_if "swapon -s | grep -q '/swap'"
end

# Gitlab

node[:gitlab] ||= {}
node[:gitlab][:rpm] ||= "https://downloads-packages.s3.amazonaws.com/centos-7.1.1503/gitlab-ce-7.10.1~omnibus-1.x86_64.rpm"
package_name = node[:gitlab][:rpm].split("/").last.sub(/\.rpm$/, "")

execute "install gitlab rpm" do
  command "rpm -i #{node[:gitlab][:rpm]}"
  not_if "rpm -q #{package_name}"
end

execute "reconfigure gitlab" do
  command "gitlab-ctl reconfigure"
  action :nothing
end

if /^https/ =~ node[:gitlab][:external_url]
  directory "/etc/gitlab/ssl" do
    mode "0700"
  end
  remote_file "/etc/gitlab/ssl/gitlab.crt" do
    source "ssl/gitlab.crt"
  end
  remote_file "/etc/gitlab/ssl/gitlab.key" do
    source "ssl/gitlab.key"
  end
end

template "/etc/gitlab/gitlab.rb" do
  source "templates/gitlab.rb.erb"
  notifies :run, "execute[reconfigure gitlab]"

  variables(
    gitlab_rails: node[:gitlab][:gitlab_rails] || {},
    nginx: node[:gitlab][:nginx] || {}
  )
end
