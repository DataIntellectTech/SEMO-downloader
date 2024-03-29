# SEMO-downloader

The purpose of this TorQ app is to provide an environment where users can download and store data relevent to electricity production for both NI and ROI. The app can be used to perfrom bespoke analysis of electric market data sourced from the [SEMOpx API](https://www.semopx.com/documents/general-publications/SEMOpx-Website-Report-API.pdf), and weather data obtained from the [Tomorrow.io API](https://www.tomorrow.io/data-catalog/), in either kdb+ or Python, as well the ability to display this data using customized plots via the kdb+ Plugin for Grafana.

# Installation

Requires kdb+. For Linux users, SEMO-downloader can be installed by running the following lines:
```
mkdir SEMOTorQ;cd SEMOTorQ
git clone https://github.com/AquaQAnalytics/TorQ.git
git clone https://github.com/AquaQAnalytics/SEMO-downloader.git
mkdir deploy deploy/hdb
cp -r TorQ/* deploy/
cp -r SEMO-downloader/* deploy/
```
Once installed we can then move into our `deploy` directory, set the required environment variables using `setenv.sh`.

```
cd deploy
. setenv.sh
```

### Quick Setup Guide

To make use of the weather forecasting information you will first need to register for a free API key from the [Tomorrow.io weather API website](https://app.climacell.co/signup?planid=5fa4047f4acee993fbd7399d&vid=4799811d-3dd8-49fa-9e91-04be3b5de3e1). Then replace the placeholder API key in apikey.txt with your own. To get weather data about a specific location you should update the lat_lon.csv with the latitude and longitude of that specific location along with an associated location sym. Note that the free version of the ClimaCell gives access to 1000 calls per day and each cluster requires 48 calls per day.

To backfill the HDB with the SEMOpx Reports run
```
./torq.sh debug semodownloader1
.semo.backload[.z.d-100;.z.d]
```

Finally start the stack which can be achieved with `./torq.sh start all`

## SEMOpx Reports & Corresponding kdb+ Tables

The SEMO-downloader loads in five different SEMOpx reports, using the SEMOpx API. These reports are then formatted into six seperate tables, the summary table below shows the reports loaded and their corresponding tables:

| Report ID       | Report Name           | Corresponding Table(s)  | kdb+ Table Name |
| ------------- |-------------| -------|-------|
| EA-001      | ETS Market Results | Index Prices <br> Linear Orders <br> Complex Orders | ``indexprices`` <br> ``linearorders`` <br> ``complexorders`` |
| BM-009      | Annual Load Forecast | Load Forecast | ``loadforecast`` |
| BM-010      | Daily Load Forecast | Load Forecast | ``loadforecast`` |
| BM-013      | Four Day Aggregated Rolling Wind Unit Forecast | Four Day Aggregated Rolling Wind Unit Forecast | ``fourdayaggrollwindunitfcst``
| BM-025      | Imbalance Price Report | Minimum Imbalance | ``imbalancepricereport``

A brief description of each of these tables is given below. The full details of the data contained in each of the reports which make up these tables can be found in the [SEMOpx Data Publication Guide](https://www.semopx.com/documents/general-publications/SEMOpx_Data_Publication_Guide.zip).  

### Index Prices

The Index Prices table contains index price data for the Day Ahead, Intraday 1, Intraday 2 & Intraday 3 auctions. The ETS Market Results report, which this table is formatted from, is published once daily for the prior trading day, excluding weekends (where the data for Friday, Saturday & Sunday is published on the Monday).  

| Column Header | Description |
| ----- | ----- |
| date  | Partition Date |
| datetime | Timestamp     |
| priceeur    | Index Price in EUR      |
| pricegbp    | Index Price in GBP      |
| volume      | Index Volume       |
| position    | Net Position Volume |
| auctionname | Distinguishes between each of the day ahead and intraday auctions: <br> SEM_DA, SEM_IDA1, SEM_IDA2, SEM_IDA3  |
| marketarea  | Distinguishes between auctions in NI & ROI | 

### Linear & Complex Orders

Both the Linear & Complex Order tables share the same schema, presenting data on given orders including their quantity, settlement currency, the member who made the order, the portfolio it was under and the auction it corresponded to.    

| Column Header | Description |
| ----- | ----- |
| date      | Partition Date      |
| datetime      | Timestamp      |
| quantity      | Value of executed quantity for that order      |
| orderperiodid      | Order ID number for that specific period    |
| memname      | Member's Trade Name      |
| fullmemname      | Member's Full Trade Name      |
| currency      | Settlement currency  <br> EUR, GBP    |
| pfname      | Name of portfolio <br> [Further details](https://www.sem-o.com/training/modules/balancing-market-registration/Entity-Model.pdf) |
| auctionname      | Distinguishes between each of the day ahead and intraday auctions      |

### Load Forecast

The Load Forecast table contains the daily & annually predicted load forecasts for ROI, NI and their aggregate; the ``fcsttype`` indicates whether a given forecast was made in an annual or daily report. The report containing the annual predictions (BM-009) is published in August, and contains forecasts for the coming trading year. The report containing the daily predictions (BM-010) is published every four calendar days and contains load forecasts for the following four days.     

| Column Header | Description |
| ----- | ----- |
| date      | Date the Forecast was made on |
| forecasteddate | Date being forecast       |
| starttime      | Start time of predicted period       |
| endtime      | End time of predicted period      |
| loadfcstroi      | Load Forecast for ROI (MW)  |
| loadfcstni      | Load Forecast for NI (MW)       |
| aggregatedfcst      | Aggregated Load Forecast for both Jurisdictions      |
| fcsttype      | Indicates whether table entry was forecasted daily or annually |
| filename      | Name of the individual report file the data was extracted from      |

### Four Day Aggregated Rolling Wind Unit

The Four Day Aggregated Rolling Wind Unit table contains the Forecasted Aggregate Output (MW) across all Wind Units in each jurisdiction, for the next four trading days. The BM-013 Report from where this table is obtained is published four times daily.

| Column Header | Description |
| ----- | ----- |
| date      | Partition Date      |
| starttime      | Start time of predicted period      |
| endtime      | End time of predicted period      |
| loadforecastroi      | Load Forecast for ROI (MW)       |
| loadforecastni      | Load Forecast for NI (MW)      |
| aggregatedforecast      | Aggregated Load Forecast for both Jurisdictions    |


### Minimum Imbalance

The Minimum Imbalance table contains data related to the calculation of the imbalance price for a given imbalance pricing period and is published following the end of its calculation. The Imbalance Price is used to settle energy imbalance volumes, where there is a difference between the amount of power produced and the amount of electricity contracted.

| Column Header | Description |
| ----- | ----- |
| date  | Partition Date      |
| start | Start time of the Imbalance Price Period |
| end | End time of the Imbalance Price Period  |
| netimbalancevol | Net Imbalance Volume |
| defaultpxusage | Default price used ‘Y’ or ‘N’ |
| asppxusage | Administered Scarcity Price used ‘Y’ or ‘N’ |
| totunitavail | Total Availability of all Units |
| demandctrlvol | Demand Control Volume |
| pmea | Price of the Marginal Energy Action in EUR |
| qpar | Quantity Price Average Reference |
| administeredscarcitypx | Administered Scarcity Price in EUR |
| imbalancepx | Imbalance Price in EUR for the Imbalance Pricing Period |
| marketbackuppx | Market Backup Price applicable for the Imbalance Settlement Period |
| shorttermreservequantity | Short Term Reserve Quantity |
| operatingreserverequirement | Operating Reserve Requirement |

## Grafana and kdb+ Plugin Quick Installation
The following is a quick guide to installing Grafana with the kdb+ datasource plugin. For a more detailed guide please refer to the full guide on the [KDB+ datasource plugin's GitHub](https://github.com/AquaQAnalytics/grafana-kdb-datasource-ws/blob/master/Readme.md). 

#### Install Grafana:
Install the latest version of [Grafana](https://grafana.com/grafana/download/7.3.4), the version used in this repo is Grafana v7.3.4.

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
First ensure that the kdb+ instance we wish Grafana to interact with is on an [open listening port](https://code.kx.com/q/basics/listening-port/). Then in order for Grafana to communicate with our kdb+ process we must assign the following custom .z.ws WebSocket message handler on that kdb+ instance:

``.z.ws:{ds:-9!x;neg[.z.w] -8! `o`ID!(@[value;ds[`i];{`$"'",x}];ds[`ID])}``

This function can be set up over a remote handle, qcon or by including it within the base code used to start that process.


#### Adding datasource:
Once the kdb+ instance is configured, start up Grafana (*default address: http://localhost:3000*) and add that kdb+ instance as a datasource. To do this, navigate to the data sources page in Grafana by hovering over the cog icon on the left side of the page, then select Data Sources. Once selected, click *Add data source*, using the search bar, search `kdb+`, click on data source labeled kdb+ to set settings related to that kdb+ instance.  

*Host* should be only the address and port of the kdb+ instance given as:

`ADDRESS:PORT`

*'ws://' is not required, processes running on the same machine have `localhost` address.*

Default Timeout is how long in ms each query will wait for a response (will default to 5000 ms).

## Importing our Example Dashboard

Once the SEMO Downloader and the Grafana kdb+ Plugin have been installed, a dashboard in Grafana can be set up to view the SEMO data. An example dashboard has been included with this repository named ``SEMOpxExampleDashboard.json``, which should give a brief introduction to visualisations of kdb+ data using the Grafana Plugin.

Once in Grafana, to import this dashboard simply navigate to the left hand side, click on the plus and then import. Next click upload JSON file and select the example dashboard JSON file included with this code repository. You can then give your dashboard a different name and Unique Identifier, and are required to select the kdb+ datasource which corresponds to your SEMO historical data. Once selected click the import button, the example dashboard should now been shown on screen, showing the SEMO data.

![](images/dashboard.PNG?raw=true "Example Dashboard")

## Data Quality
The quality of the data obtained using the SEMO-downloader can also be visually checked against the data presented by EirGrid on their [online dashboard](http://smartgriddashboard.eirgrid.com/#all/market-pricing). Below shows an example of this for the Imbalance Pricing data:

![](images/grafana_imbalance.PNG?raw=true)  
![](images/eirgrid_imbalance.PNG?raw=true)

Note that in both of these graphs the raw data has been bucketed into 30 minute intervals.

## Interacting with this kdb+ data via qPython
As well as using Grafana to visualise the data obtained using the SEMO-downloader, we can also use qPython, a kdb+ interfacing library for Python, and Jupyter Notebooks to interact with it directly. An example script and identical notebook are included in the ``code/python`` directory, however a simple guide to setting this up is shown below.

### Install Anaconda
In order to use Python & Jupyter Notebooks to view the data we need to install the latest version of [Anaconda](https://www.anaconda.com/products/individual). For reference the example shown below uses conda 4.9.2, and Python 3.8.5, with the default Anaconda install options.

### Install qPython
Once Anaconda has been installed, open an Anaconda prompt and download [qPython](https://pypi.org/project/qPython/) using pip.
```
pip install qPython
```
### Getting the Data from a kdb+ process
After installing the qPython library open a new Jupyter Notebook, and ensure the install was successful by running, ``import qpython``, if no error occurs the module has been installed successfully.

The following is a brief example on connecting to a kdb+ process with qPython and making a simple plot using [Plotly](https://plotly.com/) Python Library, which can be [downloaded using conda](https://anaconda.org/plotly/plotly), via the Anaconda prompt.
```
conda install -c plotly plotly
```

First import the QConnection function from qPython and the express class from Plotly to make a plot. 
```python
from qpython.qconnection import QConnection
import plotly.express as px
```
Then make a connection to an exisiting kdb+ HDB process which contains the data obtained by the SEMO-downloader. Using this connection we can make a simple query to get the indexprices in EUR for the day ahead auction for a period between 2020.12.10 and 2020.12.12.
```python
with QConnection(host = '<hostname>', port = <portnumber>, username = '<user>', password = '<pass>') as q:
    data=q("""select datetime,priceeur from indexprices where date within (2020.12.10; 2020.12.12), 
           auctionname=`SEM_DA, marketarea=`ROI_DA""", pandas = True)
```
The ``pandas=True`` option shown above ensures that the data is returned in a [pandas DataFrame](https://pandas.pydata.org/pandas-docs/stable/reference/api/pandas.DataFrame.html), (additional options can be found in the [qPython documentation](https://qpython.readthedocs.io/en/latest/index.html)).

Lastly, we plot the data using Plotly, which is done in the following lines of code:
```python
fig = px.line(data, x='datetime', y="priceeur", 
              labels={"priceeur":"Price (£/MWh)","datetime":"Date Time"},
             title="Index Price")
fig.show()
```
![](images/example_plot.PNG?raw=true "Example Plot")



