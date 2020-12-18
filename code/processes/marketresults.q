.proc.loadf[(getenv`KDBAPPCODE),"/common/req.q"]

\d .semo

hdbdir:@[value;`hdbdir;hsym`$getenv`KDBHDB]
codedir:@[value;`codedir;hsym`$getenv`KDBAPPCODE]

reportbackup:"reportfiles/"

/ base url for ETS market results files
mrurl:"https://reports.semopx.com/api/v1/documents/static-reports?ResourceName=MarketResult_SEM"

/ base url for minimum imbalance files
miurl:"https://reports.sem-o.com/api/v1/documents/static-reports?ResourceName=PUB_5MinImbalPrc_&page_size=600"

/ base url for annual load forecast files
aurl:"https://reports.sem-o.com/api/v1/documents/static-reports?ResourceName=PUB_annualLoadFcst_"

/ base url for daily load forecast files
dlfurl:"https://reports.sem-o.com/api/v1/documents/static-reports?ResourceName=PUB_DailyLoadFcst_"

/ base url for four day roll wind unit forecast files
fdrufurl:"https://reports.sem-o.com/api/v1/documents/static-reports?ResourceName=PUB_4DayRollWindUnitFcst_"

/ base url for four day aggregated roll wind unit forecast files
fdarufurl:"https://reports.sem-o.com/api/v1/documents/static-reports?ResourceName=PUB_4DayAggRollWindUnitFcst_"

/ base url for imbalance price report files
iprurl:"https://reports.sem-o.com/api/v1/documents/static-reports?ResourceName=PUB_30MinAvgImbalPrc_"

datelink:{[sd;ed;url]sd:ssr[string sd;".";"-"];ed:ssr[string ed;".";"-"] ;url,"&","Date=%3E",sd,"%3C=",ed}

publishlink:{[sd;ed;url]sd:ssr[string sd;".";"-"];ed:ssr[string ed;".";"-"] ;url,"&","PublishTime=%3E",sd,"%3C=",ed}

filesearchlink:{[sd;ed;url;b]           / set b to 1 for datelink,
  $[b;                                  / 0 for publishlink
    .semo.datelink[sd;ed;url];
    .semo.publishlink[sd;ed;url]]}

getfilenames:{[sd;ed;url;b]
  t:.req.g[.semo.filesearchlink[sd;ed;url;b]][`items;;`ResourceName]}

getfile:{[filename]                     / returns contents of input file
  .req.g["https://reports.semopx.com/documents/" ,filename]}

getfiles:{[sd;ed;url;b]
  getfile each getfilenames[sd;ed;url;b]}



/ extracts data fields from string
len:{2*til `int$0.5*1+count -4!x}

/ normalises dates
dates:{x:ssr[x;"-";"."];
  x:ssr[x;"Z";""];
  x:("Z"$-4!x).semo.len[x]}

/ inserts null values
nulls:{x:ssr[x;";;";";0N;"];
  x:ssr[x;";;";";0N;"];
  x:$[";"=first x;"0N",x;x];
  x:$[";"=last x;x,"0N";x];
  x:("J"$-4!x).semo.len x}

/ normalises floats
floats:{x:ssr[x;",";"."];
  x:("F"$-4!x).semo.len x}

/ normalises timestamps
tmstmp:{x:ssr[x;"-";"."];
  x:ssr[x;"T";"D"];
  `timestamp$parse x}

/ searches a line of the xml for a specific word and grabs the corresponding data entry
getentry:{[xml;line;word]
  pos:first ss[xml[line];word];
  c:(1;0)+2#1_distinct d*pos<d:where xml[line]="\"";
  c[0]_c[1]#xml[line]}

/ normalises prices
prices:{x:ssr[x;",";""];
  x:0.001*("I"$-4!x).semo.len x}

/ extracts the market area
marketarea:{x:parse (,/)4_-4!ssr[x 0;"-";"_"]}

/ extracts the areaset
areaset:{parse ssr[(,/)4_-4!x;"-";"_"]}

/ extracts the auctionname
auctionname:{parse ssr[ssr[(,/)4_-4!x;"-";"_"];"+";"_"]}

/ extracts the blockname
blockname:{(-4!ssr[11_x;"-";"_"]).semo.len[x]}

/ extracts the block price
blockprice:{parse each (-4!ssr[12_x;",";"."]).semo.len[x]}

/ extracts the block volume
blockvol:{parse each (-4!ssr[12_x;",";"."]).semo.len[x]}





/ linear or complex order table at line x of a given file
lotable:{x:#[-5;#[5+x;y]],2#y;
  c:count ([]time:.semo.dates x 2);
  ([]date:`date$' .semo.dates x 2;
    datetime:`timestamp$' .semo.dates x 2;
    quantity:.semo.floats x 3;
    orderperiodid:.semo.nulls x 4;
    memname:c#parse(-4!x 0)[2];
    fullmemname:c#parse(-4!x 1)[4];
    currency:c#parse(-4!x 0)[8];
    pfname:c#parse(-4!x 0)[4];
    auctionname:c#.semo.areaset[x[5]])}

/ index price table at line x of file
ipxtable:{x:_[x;#[21+x;y]],2#y;
  c:count ([]prices:.semo.prices x 3);
  ([]date:`date$.semo.dates x 2;
    datetime:`timestamp$ .semo.dates x 2;
    priceeur:.semo.prices x 3;
    pricegbp:.semo.prices x 6;
    volume:.semo.floats x 9;
    position:.semo.floats x 12;
    auctionname:c#.semo.areaset[x[21]];
    marketarea:.semo.marketarea x)}

/ creates single table entry for the minimum imbalance table
minimbal:{[xml]
  k:$[240<count xml[2];1;0];
  ([]tradedate:enlist `date$.semo.tmstmp .semo.getentry[xml;2;"TradeDate="];
    start:enlist .semo.tmstmp .semo.getentry[xml;2;"StartTime="];
    end: enlist each .semo.tmstmp .semo.getentry[xml;2;"EndTime="];
    netimbalancevol:enlist $[k;`float$parse .semo.getentry[xml;2;"NetImbalanceVolume="];0n];
    defaultpxusage: enlist parse .semo.getentry[xml;2;"DefaultPriceUsage="];
    asppxusage: enlist parse .semo.getentry[xml;2;"ASPPriceUsage="];
    totunitavail: enlist $[k;`float$parse .semo.getentry[xml;2;"TotalUnitAvailability="];0n];
    demandctrlvol: enlist $[k;`float$parse .semo.getentry[xml;2;"DemandControlVolume="];0n];
    pmea: enlist $[k;`float$parse .semo.getentry[xml;2;"PMEA="];0n];
    qpar: enlist $[k;`float$parse .semo.getentry[xml;2;"QPAR="];0n];
    administeredscarcitypx: enlist $[k;`float$parse .semo.getentry[xml;2;"AdministeredScarcityPrice="];0n];
    imbalancepx: enlist $[k;`float$parse .semo.getentry[xml;2;"ImbalancePrice="];0n];
    marketbackuppx: enlist $[.semo.getentry[xml;2;"MarketBackupPrice="] like "* TradeDate=*";0n;`float$parse .semo.getentry[xml;2;"MarketBackupPrice="]];
    shorttermreservequantity: enlist $[k;`float$parse .semo.getentry[xml;2;"ShortTermReserveQuantity="];0n];
    operatingreserverequirement: enlist $[k;`float$parse .semo.getentry[xml;2;"OperatingReserveRequirement="];0n])}

/ creates annual table entry using data starting at line l
annualtable:{[d;t;l;f]
  data:#[6;_[1+l;t]];
  line:{[d;r] _[1+first where ">"=d[r];#[last where "<"=d[r];d[r]]]};
  deliverydate:`date$' first `date$.semo.dates[line[data;0]];
  starttime: first .semo.dates[line[data;1]];
  endtime: first .semo.dates[line[data;2]];
  loadforecastroi:first `int$.semo.floats[line[data;3]];
  loadforecastni:first `int$.semo.floats[line[data;4]];
  aggregatedforecast:first `int$.semo.floats[line[data;5]];
  predictiontime:first `datetime$parse ssr[_[-2;#[-21;t[1]]];"-";"."];
  table:([]date:enlist parse (string -1+`year$starttime),".08.01";
    forecasteddate:enlist `date$starttime;
    starttime:enlist `timestamp$starttime;
    endtime:enlist `timestamp$endtime;
    loadfcstroi:enlist loadforecastroi;
    loadfcstni:enlist loadforecastni;
    aggregatedfcst:enlist aggregatedforecast;
    fcsttype:`annual;
    filename:f)}

/ creates daily load forecast tble entry using data starting at line l
dailyloadforecasttable:{[d;t;l;f]
  data:#[7;_[1+l;t]];
  line:{[d;r] _[1+first where ">"=d[r];#[last where "<"=d[r];d[r]]]};
  date:`date$first `date$.semo.dates[line[data;0]];
  forecastdate:`date$first `date$.semo.dates[line[data;1]];
  starttime:first .semo.dates[line[data;2]];
  endtime:first .semo.dates[line[data;3]];
  loadforecastroi:first `int$.semo.floats[line[data;4]];
  loadforecastni:first `int$.semo.floats[line[data;5]];
  aggregatedforecast:first `int$.semo.floats[line[data;6]];
  predictiontime:first `datetime$parse ssr[_[-2;#[-21;t[1]]];"-";"."];
  table:([]date:enlist min(d;`date$starttime);
    forecasteddate:enlist `date$predictiontime;
    starttime:enlist `timestamp$starttime;
    endtime:enlist `timestamp$endtime;
    loadfcstroi:enlist loadforecastroi;
    loadfcstni:enlist loadforecastni;
    aggregatedfcst:enlist aggregatedforecast;
    fcsttype:`daily;
    filename:f)}

imbalancepricereporttable:{[text]
  ([] tradedate:enlist parse ssr[.semo.getentry[text;2;"TradeDate"];"-";"."];
  starttime:enlist parse ssr[ssr[.semo.getentry[text;2;"StartTime"];"-";"."];"T";"D"];
  endtime:enlist parse ssr[ssr[.semo.getentry[text;2;"EndTime"];"-";"."];"T";"D"];
  netimbalancevolume:enlist $[-9=type parse .semo.getentry[text;2;"NetImbalanceVolume"];parse .semo.getentry[text;2;"NetImbalanceVolume"];0n];
  imbalancesettlementprice:enlist `float$parse .semo.getentry[text;2;"ImbalanceSettlementPrice"];
  publishtime:enlist parse ssr[ssr[.semo.getentry[text;1;"PublishTime"];"-";"."];"T";"D"])}

imbalancepricereport:{files:.semo.getfiles[x;x+1;.semo.iprurl;0];
  files:files where 3<count each files;
  $[count files;`starttime xasc (uj/).semo.imbalancepricereporttable each vs["\r\n";] each files;]}

createfourdayaggrollwindunitfcst:{[text]
  pos:where text like "*  <PUB_4DayAggRollWindUnitFcst*";
  (uj/){[text;pos;x]
  ([]deliverydate:enlist parse ssr[.semo.getentry[text;pos[x];"DeliveryDate"];"-";"."];
     starttime:enlist `timestamp$parse ssr[ssr[.semo.getentry[text;pos[x];"StartTime"];"-";"."];"T";"D"];
     endtime:enlist `timestamp$parse ssr[ssr[.semo.getentry[text;pos[x];"EndTime"];"-";"."];"T";"D"];
     loadforecastroi:enlist $[-9=type parse .semo.getentry[text;pos[x];"LoadForecastROI"];parse .semo.getentry[text;pos[x];"LoadForecastROI"];0n];
     loadforecastni:enlist last $[-9=type parse .semo.getentry[text;pos[x];"LoadForecastNI"];parse .semo.getentry[text;pos[x];"LoadForecastNI"];0n];
     aggregatedforecast:enlist $[-9=type parse .semo.getentry[text;pos[x];"AggregatedForecast"];parse .semo.getentry[text;pos[x];"AggregatedForecast"];0n])}[text;pos;] peach til count pos}

fourdayaggrollwindunitfcst:{files:.semo.getfiles[x;x+1;.semo.fdarufurl;0];
  $[count files;`starttime xasc (uj/) .semo.createfourdayaggrollwindunitfcst each vs["\r\n";] each files;]}


/ creates the entire linear order table in one file
createlo:{[file]
  pos:(-1+where file like "*Linear order*") inter where file like "*Portfolio*";
  (,/).semo.lotable[;file] each pos}

/ creates the entire complex order table in one file
createco:{[file]
  pos:(-1+where file like "*Complex order*") inter where file like "*Portfolio*";
  (,/).semo.lotable[;file] each pos}

/ creates the entire index prices table in one file
createipx:{[file]  pos:where file like "*Market Area*";
  (,/).semo.ipxtable[;file] each pos}

/ creates the entire annual load forecast table in one file
createannualtable:{[date;text;filenames] text:raze text;
  pos: where (26#'text) like "*  <PUB_AnnualLoadFcst ROW=*";
  (uj/).semo.annualtable[date;text;;filenames]each pos}

/ creates the entire daily load forecast table in one file
createdailyloadforecasttable:{[date;text;filenames]
  pos:{where (26#'x) like "* <PUB_DailyLoadFcst ROW=*"}each text;
  c:count text;
  (uj/){[text;pos;filenames;x](uj/).semo.dailyloadforecasttable[.z.d;text[x];;filenames[x]]each pos[x]}[text;pos;filenames;]each til c}

/ creates the linear order table from date x
linearorders:{files:.semo.getfiles[x;x+1;.semo.mrurl;0];
  $[count files;
    $[max 0<count each .semo.createlo each vs["\r\n";]each files;
      `datetime xasc (uj/) tbl where 0<(count each tbl:.semo.createlo each vs["\r\n";] each files);];]}

/ creates the complex order table from date x
complexorders:{files:.semo.getfiles[x;x+1;.semo.mrurl;0];
  $[count files;
    $[max 0<count each .semo.createco each vs["\r\n";]each files;
      `datetime xasc (uj/) tbl where 0<(count each tbl:.semo.createco each vs["\r\n";] each files);];]}

/ creates the index prices table from date x
indexprices:{files:.semo.getfiles[x;x+1;.semo.mrurl;0];
  $[count files;`datetime xasc (uj/) tbl where 0<(count each tbl:.semo.createipx each vs["\r\n";]each files);]}

/ creates the minimum imbalance table from date x
minimumimbalance:{files:vs["\r\n";]each .semo.getfiles[x;x+1;.semo.miurl;0];
  files:files where 4<count each files;
  $[count files;`start xasc (uj/) (.semo.minimbal  each files);]}

/ creates the annual load forecast table from date x
annualloadforecast:{text:vs["\r\n";]each .semo.getfiles[x;x+1;.semo.aurl;0];
  filenames:.semo.getfilenames[x;x+1;.semo.aurl;0];
  filenames:first $[count text;parse each filenames;()];
  $[count text;
    .semo.createannualtable[x;text;filenames];
    ]}

/ creates the daily load forecast table from date x
dailyloadforecast:{text:.semo.getfiles[x;x+1;.semo.dlfurl;0];
  text:vs["\r\n";]each text c:where 10<count each text;
  filenames:parse each .semo.getfilenames[x;x+1;.semo.dlfurl;0];
  filenames:filenames c;
  $[count text;
    .semo.createdailyloadforecasttable[x;text;filenames];
    ]}

/ joins the daily load forecast table and the annual load forecast table from date x to create the load forecast table
loadforecast:{a:.semo.annualloadforecast[x];
  b:.semo.dailyloadforecast[x];
  $[1<count a;$[1<count b;`date xasc a uj b; `date xasc a];
      $[1<count b; `date xasc b; ()]]}

filesave:{[x;url;b]t:(enlist each parse each {-4_ssr[ssr[x;"-";"_"];"+";"_"]} each .semo.getfilenames[x;x+1;url;b]),'enlist each .semo.getfiles[x;x+1;url;b];
  {[t;c]set[first t[c];last t[c]]}[t;]each til count t;
  {[t;x]save `$.semo.reportbackup,string first t x}[t;]each til count t}




/ loads in and saves down the index prices table for a given day
saveipx:{$[98h=type indexprices:.semo.indexprices[x];
  {[t;d](` sv .Q.par[.semo.hdbdir;d;`indexprices],`) upsert .Q.en[.semo.hdbdir;]`datetime xasc delete date from select from t where date = d}[indexprices]each exec distinct date from select distinct date from indexprices;
  ];
  .semo.filesave[x;.semo.mrurl;0]}

/ loads in and saves down the linear orders table for a given day
savelo:{$[98h=type linearorders:.semo.linearorders[x];
  {[t;d](` sv .Q.par[.semo.hdbdir;d;`linearorders],`) upsert .Q.en[.semo.hdbdir;]`datetime xasc delete date from select from t where date = d}[linearorders]each exec distinct date from select distinct date from linearorders;
  ];
  .semo.filesave[x;.semo.mrurl;0]}

/ loads in and saves down the complex orders table for a given day
saveco:{$[98h=type complexorders:.semo.complexorders[x];
  {[t;d](` sv .Q.par[.semo.hdbdir;d;`complexorders],`) upsert .Q.en[.semo.hdbdir;]`datetime xasc delete date from select from t where date = d}[complexorders]each exec distinct date from select distinct date from complexorders;
  ];
  .semo.filesave[x;.semo.mrurl;0]}

/ loads in and saves down the minimum imbalance table for a given day
savemi:{$[98h=type minimumimbalance:.semo.minimumimbalance[x];
  {[t;d](` sv .Q.par[.semo.hdbdir;d;`minimumimbalance],`) upsert .Q.en[.semo.hdbdir;]`start xasc delete tradedate from select from t where tradedate = d}[minimumimbalance]each exec distinct tradedate from select distinct tradedate from minimumimbalance;
  ];
  .semo.filesave[x;.semo.miurl;0]}

/ loads in and saves down the load forecast table for a given day
savelf:{$[98h=type loadforecast:.semo.loadforecast[x];
  {[t;d](` sv .Q.par[.semo.hdbdir;d;`loadforecast],`) upsert .Q.en[.semo.hdbdir;]`starttime xasc delete date from select from t where date = d}[loadforecast]each exec distinct date from select distinct date from loadforecast;
  ];
  .semo.filesave[x;;0]each (.semo.dlfurl;.semo.aurl)}

/ loads in and saves down the load forecast table for a given day
savefdarwuf:{$[98h=type fourdayaggrollwindunitfcst:.semo.fourdayaggrollwindunitfcst[x];
  {[t;d](` sv .Q.par[.semo.hdbdir;d;`fourdayaggrollwindunitfcst],`) upsert .Q.en[.semo.hdbdir;]`starttime xasc delete deliverydate from select from t where deliverydate = d}[fourdayaggrollwindunitfcst]each exec distinct deliverydate from select distinct deliverydate from fourdayaggrollwindunitfcst;
  ];
  .semo.filesave[x;.semo.fdarufurl;0]}

/ loads in and saves down the imbalance price report table for a given day
saveipr:{$[98h=type imbalancepricereport:.semo.imbalancepricereport[x];
  {[t;d](` sv .Q.par[.semo.hdbdir;d;`imbalancepricereport],`) upsert .Q.en[.semo.hdbdir;]`starttime xasc delete tradedate from select from t where tradedate = d}[imbalancepricereport]each exec distinct tradedate from select distinct tradedate from imbalancepricereport;
  ];
  .semo.filesave[x;.semo.iprurl;0]}



/ calls all the table saving functions for a given day and then fills the hdb
savedown:{.semo.savelo[.z.d];
  .semo.saveco[.z.d];
  .semo.saveipx[.z.d];
  .semo.savemi[.z.d];
  .semo.savelf[.z.d];
  .semo.savefdarwuf[.z.d];
  .semo.saveipr[.z.d];
  .Q.chk .semo.hdbdir}

bl:{.semo.savelo[x];
  .semo.saveco[x];
  .semo.saveipx[x];
  .semo.savemi[x];
  .semo.savelf[x];
  .semo.savefdarwuf[x];
  .semo.saveipr[x];
  .Q.chk .semo.hdbdir;
  0N!x}

backload:{[sd;ed].semo.bl each asc sd+til 1+ed-sd}


.timer.repeat[05:00+.z.d;0W;1D00:00:00;(`.semo.savedown;`);"Save SEMO market data"]
