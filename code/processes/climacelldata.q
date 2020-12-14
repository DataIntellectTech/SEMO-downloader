\d .clma 




// CLUSTER LOCATIONS
latlon:((55.50234;-6.20000;0);
  (52.00000;-6.00000;1);
  (27.80000;-2.45000;2))


.servers.startup[]

hdbdir:@[value;`hdbdir;hsym`$getenv`KDBHDB]
tphandle:.servers.gethandlebytype[`tickerplant;`any]
codedir:@[value;`codedir;hsym`$getenv`TORQAPPHOME]
reportbackup:@[value;`reportbackup;hsym`$getenv`TORQAPPHOME],"/reportfiles/"

apikey:read0 `$raze (string codedir),"/apikey.txt"

lat_lon:value each ("ffj";enlist",")0: `$raze (string codedir),"/lat_lon.csv"

// FORECAST TYPE
realtime:"https://api.climacell.co/v3/weather/realtime?unit_system=si&"
nowcast:"https://api.climacell.co/v3/weather/nowcast?unit_system=si&timestep=5&"
hourly:"https://api.climacell.co/v3/weather/forecast/hourly?unit_system=si&"
daily:"https://api.climacell.co/v3/weather/forecast/daily?unit_system=si&"

// HISTORICAL TYPE
climacell:"https://api.climacell.co/v3/weather/historical/climacell?timestep=5&unit_system=si&"
station:"https://api.climacell.co/v3/weather/historical/station?unit_system=si&"


ll:{"lat=",(string x 0),"&lon=",string x 1}
clusters:{ll each lat_lon}



tmstp:{$[all x="now";x;ssr[ssr[19#string x;".";"-"];"D";"T"],"Z"]}

time:{[st;et]"start_time=",.clma.tmstp[st],"&end_time=",.clma.tmstp[et],"&"}

fieldsfcst:"fields=temp%2Cfeels_like%2Cwind_speed%2Cwind_gust%2Csunrise%2Csunset%2Ccloud_cover%2Csurface_shortwave_radiation%2Cprecipitation%2Cprecipitation_type%2Cprecipitation_probability&apikey=",.clma.apikey

fieldsobs:"fields=temp%2Cfeels_like%2Cwind_speed%2Cwind_gust%2Csunrise%2Csunset%2Ccloud_cover%2Csurface_shortwave_radiation%2Cprecipitation%2Cprecipitation_type&apikey=",.clma.apikey
url:{[ft;cl;st;et;fd]ft,cl,"&",time[st;et],fd}

getdata:{[url].j.k raze system"curl \"",url,"\""}
jsonget:{[clm;t] first each first each ?[t;();0b;((enlist clm)!enlist clm)]}
jsongettmstmp:{[clm;t]"P"$-1_'ssr[;"-";"."]each jsonget[clm;t]}
singleweatherfcst:{[cl;st;et]jsontable:.clma.getdata[raze .clma.url[.clma.hourly;cl;st;et;fieldsfcst]];
  t:flip(cols jsontable)!((@[.clma.jsonget[;jsontable]each 11#cols jsontable;4;parse each ssr[;" ";"_"]each (,/) each]),(jsongettmstmp[;jsontable]each -3#cols jsontable));
  t:(-1 rotate cols t) xcols t;
  c:count t;
  d:(enlist each 500 xbar `int$1000000*2#'.clma.lat_lon)!(enlist each 2_'.clma.lat_lon);
  (select date:`date$observation_time, observation_time from t),'([]cluster_sym:first each first each d enlist each 500 xbar `int$1000000*(,'/)exec lat,lon from t),'t ,' select time_until:3600000 xbar `time$observation_time-.z.p from t}

singleweatherobs:{[cl;st;et]jsontable:.clma.getdata[raze .clma.url[.clma.climacell;cl;st;et;fieldsobs]];
  t:flip(cols jsontable)!((@[.clma.jsonget[;jsontable]each 10#cols jsontable;9;parse each ssr[;" ";"_"]each (,/) each]),(jsongettmstmp[;jsontable]each -3#cols jsontable));
  t:(-1 rotate cols t) xcols t;
  c:count t;
  d:(enlist each 500 xbar `int$1000000*2#'.clma.lat_lon)!(enlist each 2_'.clma.lat_lon);
  t:(select date:`date$observation_time,observation_time from t),'([]cluster_sym:first each first each d enlist each 500 xbar `int$1000000*(,'/)exec lat,lon from t),'1_'t}

weatherfcst:{[st;et]t:select from `observation_time xasc ((uj/).clma.singleweatherfcst[;st;et]each .clma.clusters `) where time_until>=0;
  t:$[98h=type t;t;];
  t:$[max 1_deltas value (cols t)!({count ?[y;();0b;(enlist x)!enlist x]}[;t]each cols t);;t]}
weatherobs:{[st;et]t:select from `observation_time xasc (uj/).clma.singleweatherobs[;st;et]each .clma.clusters `;
  t:$[98h=type t;t;];
  t:$[max 1_deltas value (cols t)!({count ?[y;();0b;(enlist x)!enlist x]}[;t]each cols t);;t]}


filesave:{[table;tp]t:(`$(string tp),"_",ssr[ssr[(string .z.d),"D",(string `second$.z.p);".";"_"];":";"_"];table);
  set[first t;last t];
  save `$raze (string .clma.reportbackup),(string t[0]),".csv"}

sendfcst:{[]
  fcst:.clma.weatherfcst["now";-00:01+.z.d+4];
  .clma.filesave[fcst;`weatherforecast];
  fcst:update sym:`$string cluster_sym from fcst;
  fcst:delete date,cluster_sym from fcst;
  weatherforecast:`sym xcols fcst;
  {.clma.tphandle(`.u.upd;`weatherforecast;x)}each value each weatherforecast;
 };

sendobs:{[]
  obs:.clma.weatherobs[-01:00+.z.p;"now"];
  .clma.filesave[obs;`weatherobserved];
  obs:update sym:`$string cluster_sym from obs;
  obs:delete date,cluster_sym from obs;
  weatherobserved:`sym xcols obs;
  {.clma.tphandle(`.u.upd;`weatherobserved;x)}each value each weatherobserved;
 };

.timer.repeat[00:00+.z.d;0W;0D01:00:00;(`.clma.sendfcst;`);"Save weather forecast"]
.timer.repeat[00:00+.z.d;0W;0D01:00:00;(`.clma.sendobs;`);"Save weather observation"]
