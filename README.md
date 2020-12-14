# SEMO-downloader

## SEMOpx Reports & Corresponding KDB+ Tables

| Report ID       | Report Name           | Corresponding Table(s)  | KDB+ Table Name |
| ------------- |-------------| -------|-------|
| EA-001      | ETS Market Results | Index Prices <br> Linear Orders <br> Complex Orders | ``indexprices`` <br> ``linearorders`` <br> ``complexorders`` |
| BM-009      | Annual Load Forecast | Load Forecast | ``loadforecast`` |
| BM-010      | Daily Load Forecast | Load Forecast | ``loadforecast`` |
| BM-013      | Four Day Aggregated Rolling Wind Unit Forecast | Four Day Aggregated Rolling Wind Unit Forecast | ``fourdayaggrollwindunitfcst``
| BM-025      | Imbalance Price Report | Minimum Imbalance | ``imbalancepricereport``

## Grafana and KDB+ Plugin Quick Installation
The following is a quick guide to installing Grafana with the kdb+ datasource plugin, for a more detailed guide please refer to the full guide on the [kdb+ datasource plugin's GitHub](https://github.com/AquaQAnalytics/grafana-kdb-datasource-ws/blob/master/Readme.md). 

#### Install Grafana:
Install the latest version of [Grafana](https://grafana.com/grafana/download/7.3.4).

#### Installing kdb+ datasource plugin:
 - Download the [latest release](https://github.com/AquaQAnalytics/grafana-kdb-datasource-ws/releases/tag/v1.0.1).
 - Extract the entire *grafana-kdb-datasource-ws* folder to {Grafana Install Directory}/grafana/data/plugins/.
 - Install the necessary dependencies for the plugin to run using npm:
```
npm install –g grunt-cli
npm install
grunt --install
``` 
 - Once the plugin has been installed with its corresponding dependencies, Grafana must be started/restarted. On the Windows Operating System this can be done using Windows services, which can acessed by running ``services.msc`` via the Windows Run box (Windows Key+r).
 
#### Configuring kdb+ instance:
First ensure that the kdb+ instance we wish Grafana to interact with is on an [open listening port](https://code.kx.com/q/basics/listening-port/). Then in order for Grafana to communicate with our kdb+ process we must set up the following custom .z.ws WebSocket message handler on that kdb+ instance:

``.z.ws:{ds:-9!x;neg[.z.w] -8! `o`ID!(@[value;ds[`i];{`$"'",x}];ds[`ID])}``

This function can be set up over a remote handle, qcon or by including it within the base code used to start that process.


#### Adding datasource:
Once the kdb+ instance is configured start up Grafana and add that kdb+ instance as a datasource, to do this navigate to the data-sources page in Grafana (*default address: http://localhost:3000*) and click *Add data source*.
At the bottom of this page under *Others* should be *KDB+*, click on this to set settings.
*Host* should be only the address and port of the kdb+ instance given as:

`ADDRESS:PORT`

*'ws://' is not required, processes running on the same machine have `localhost` address.*

Default Timeout is how long in ms each query will wait for a response (will default to 5000 ms).

### Importing our Example Dashboard

Once the SEMO Downloader and the Grafana KDB+ Plugin have been installed, a dashboard in Grafana can be set up to view the SEMO data. An example dashboard has been included with this repository named ``SEMOpxExampleDashboard.json``, which should give a brief introduction to visualisations of KDB+ data using the Grafana Plugin.

Once in Grafana, to import this dashboard simply navigate to the left hand side, click on the plus and then import. Next click upload JSON file and select the example dashboard JSON file included with this code repository. You can then give your dashboard a different name and Unique Identifier, and are required to select the KDB+ datasource which corresponds to your SEMO historical data, once selected click the import button, the example dashboard should now been shown on screen, showing the SEMO data. 
