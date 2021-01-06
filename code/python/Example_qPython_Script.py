from qpython.qconnection import QConnection
import plotly.express as px

with QConnection(host = '<hostname>', port = <portnumber>, username = '<user>', password = '<pass>') as q:
    print(q)
    data=q("""select datetime,priceeur from indexprices where date within (2020.12.10; 2020.12.12), 
           auctionname=`SEM_DA, marketarea=`ROI_DA""", pandas = True)

fig = px.line(data, x='datetime', y="priceeur", 
              labels={"priceeur":"Price (€/MWh)","datetime":"Date Time"},
             title="Index Price")
fig.show()