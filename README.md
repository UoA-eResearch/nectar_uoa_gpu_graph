# nectar_uoa_gpu_graph

Uses RGraph javascript library's Gantt chart to produce a calendar view of the GPU allocation to instances. 

* Gets data from the gpu db, which holds the GPU usage data from each VM, and gets instance metadata for GPU from the Nectar Nova DB. 
* Web page served from /var/www/html2
  * data/gpu_data.json (updated each hour. Lazy mans cgi)
  * gpu_projects.html  (The calendar)
  * js/                (cached versions of javascript libraries)

Currently the gpu_data.json file is being generated from a cron job, 5 minutes after the gpu db update from ntr-ops cron job updates the instance data. Needs a rewrite to just pull the data from the DB.
```
10,40 * * * * /root/sbin/gen_gpu_data
```
Writes to a temporary gpu_data.json file, then moves this to the web data/ directory, so the web version is always complete (should ensure this is on the same disk, so it is a rename, rather than a copy)

Currently just creates a Gantt chart for the current year.
_
## HTML Uses
* RGraph       https://www.rgraph.net/download.html
* wikk_ajax.js https://github.com/wikarekare/wikk_ajax_js.git
* jquery.js
_
### nb
RGraph needs a few mods to add pop ups for the y-axis. They are being incorporated back into the main RGraph code base, but in a slightly different form, so this code base will need an update soon (may have been incorporated already, as there have been a release since the version I coded against).

## Gen_gpu_data.rb needs
```
gem install wikk_sql wikk_json wikk_configuration
```
## RGraph.drawing.yaxis.js
Changed version of RGraph/Libraries/RGraph.drawing.yaxis.js to allow pop ups on yaxis labels. 

This shouldn't be necessary with later versions, but the javascript in gpu_projects.html will need to change.

## Relies on
* https://github.com/UoA-eResearch/gpulogger
* https://github.com/UoA-eResearch/nectar_uoa_gpudb_update
