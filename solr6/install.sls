# -*- coding: utf-8 -*-
# vim: ft=sls

{%- from "solr6/map.jinja" import solr6 with context %}
{% set config_file = "/etc/default/solr.in.sh" %}


{%- if "file" in solr6.archive %}
# User has provided a local archive for the installation
{%-   set archive_file = solr6.archive.file %}
{%- else %}
{%-   set archive_file = solr6.install_dir ~ '/solr-' ~ solr6.version ~ '.tgz' %}

{%-   if "source" in solr6.archive %}
# User has provided a custom source for the archive
{%-     set archive_src = solr6.archive.source %}
{%-     if "source_hash" in solr6.archive %}
{%-       set source_hash = solr6.archive.source_hash %}
{%-     endif %}
{%-   else %}
{%-     set archive_src = solr6.archive.host ~ solr6.archive.path ~ '/' ~ solr6.version ~ '/solr-' ~ solr6.version ~ '.tgz' %}
{%-     set source_hash = archive_src ~ '.md5' %}
{%-   endif %}

#
# The archive must be saved locally for extraction and installation
#
solr6-download:
  file.managed:
    - name: {{ archive_file }}
    - source: {{ archive_src }}
{%-   if "source_hash" is defined %}
    - source_hash: {{ source_hash }}
{%-   else %}
    - skip_verify: True
{%- endif %}
    - unless: test -f {{ config_file }}
    - require_in:
      - cmd: solr6-extract-installer
{%- endif %}


#
# Extract the installation script from the archive
#
solr6-extract-installer:
  cmd.run:
    - cwd: {{ solr6.install_dir }}
    - name: tar xzf {{ archive_file }} solr-{{ solr6.version }}/bin/install_solr_service.sh --strip-components=2
    - unless: test -f {{ config_file }}
    - prereq:
      - cmd: solr6-install


#
# Install the service using the extracted files and the saved archive
#
solr6-install:
  cmd.run:
    - cwd: {{ solr6.install_dir }}
    - name: {{ solr6.install_dir }}/install_solr_service.sh {{ archive_file }} -f -u {{ solr6.user }} -d {{ solr6.data_dir }} -p {{ solr6.port }} -s {{ solr6.service.name }}
    - unless: test -f {{ config_file }}
    - require_in:
      - file: solr6-defaults

#
# Make sure the version symlink has been updated
#
solr6-symlink:
  file.symlink:
    - name: {{ solr6.install_dir }}/solr
    - target: {{ solr6.install_dir }}/solr-{{ solr6.version }}
    - watch_in:
      - service: solr6

#
# Overwrite and manage the defaults file
#
solr6-defaults:
  file.managed:
    - name: {{ config_file }}
    - user: root
    - group: {{ solr6.group }}
    - mode: 640
    - contents: |
        SOLR_PID_DIR="{{ solr6.data_dir }}"
        SOLR_HOME="{{ solr6.data_dir }}/data"
        LOG4J_PROPS="{{ solr6.log_properties }}"
        SOLR_LOGS_DIR="{{ solr6.logs_dir }}"
        SOLR_PORT="{{ solr6.port }}"
    - watch_in:
      - service: solr6
