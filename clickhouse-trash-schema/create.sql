-- Same table settings as in ../clickhouse/create.sql.

CREATE OR REPLACE TABLE hits_staging
(
    id BIGINT NOT NULL,
    WatchID BIGINT NOT NULL,
    JavaEnable SMALLINT NOT NULL,
    Title TEXT NOT NULL,
    GoodEvent SMALLINT NOT NULL,
    EventTime TIMESTAMP NOT NULL,
    EventDate Date NOT NULL,
    CounterID INTEGER NOT NULL,
    ClientIP INTEGER NOT NULL,
    RegionID INTEGER NOT NULL,
    UserID BIGINT NOT NULL,
    CounterClass SMALLINT NOT NULL,
    OS SMALLINT NOT NULL,
    UserAgent SMALLINT NOT NULL,
    URL TEXT NOT NULL,
    Referer TEXT NOT NULL,
    IsRefresh SMALLINT NOT NULL,
    RefererCategoryID SMALLINT NOT NULL,
    RefererRegionID INTEGER NOT NULL,
    URLCategoryID SMALLINT NOT NULL,
    URLRegionID INTEGER NOT NULL,
    ResolutionWidth SMALLINT NOT NULL,
    ResolutionHeight SMALLINT NOT NULL,
    ResolutionDepth SMALLINT NOT NULL,
    FlashMajor SMALLINT NOT NULL,
    FlashMinor SMALLINT NOT NULL,
    FlashMinor2 TEXT NOT NULL,
    NetMajor SMALLINT NOT NULL,
    NetMinor SMALLINT NOT NULL,
    UserAgentMajor SMALLINT NOT NULL,
    UserAgentMinor VARCHAR(255) NOT NULL,
    CookieEnable SMALLINT NOT NULL,
    JavascriptEnable SMALLINT NOT NULL,
    IsMobile SMALLINT NOT NULL,
    MobilePhone SMALLINT NOT NULL,
    MobilePhoneModel TEXT NOT NULL,
    Params TEXT NOT NULL,
    IPNetworkID INTEGER NOT NULL,
    TraficSourceID SMALLINT NOT NULL,
    SearchEngineID SMALLINT NOT NULL,
    SearchPhrase TEXT NOT NULL,
    AdvEngineID SMALLINT NOT NULL,
    IsArtifical SMALLINT NOT NULL,
    WindowClientWidth SMALLINT NOT NULL,
    WindowClientHeight SMALLINT NOT NULL,
    ClientTimeZone SMALLINT NOT NULL,
    ClientEventTime TIMESTAMP NOT NULL,
    SilverlightVersion1 SMALLINT NOT NULL,
    SilverlightVersion2 SMALLINT NOT NULL,
    SilverlightVersion3 INTEGER NOT NULL,
    SilverlightVersion4 SMALLINT NOT NULL,
    PageCharset TEXT NOT NULL,
    CodeVersion INTEGER NOT NULL,
    IsLink SMALLINT NOT NULL,
    IsDownload SMALLINT NOT NULL,
    IsNotBounce SMALLINT NOT NULL,
    FUniqID BIGINT NOT NULL,
    OriginalURL TEXT NOT NULL,
    HID INTEGER NOT NULL,
    IsOldCounter SMALLINT NOT NULL,
    IsEvent SMALLINT NOT NULL,
    IsParameter SMALLINT NOT NULL,
    DontCountHits SMALLINT NOT NULL,
    WithHash SMALLINT NOT NULL,
    HitColor CHAR NOT NULL,
    LocalEventTime TIMESTAMP NOT NULL,
    Age SMALLINT NOT NULL,
    Sex SMALLINT NOT NULL,
    Income SMALLINT NOT NULL,
    Interests SMALLINT NOT NULL,
    Robotness SMALLINT NOT NULL,
    RemoteIP INTEGER NOT NULL,
    WindowName INTEGER NOT NULL,
    OpenerName INTEGER NOT NULL,
    HistoryLength SMALLINT NOT NULL,
    BrowserLanguage TEXT NOT NULL,
    BrowserCountry TEXT NOT NULL,
    SocialNetwork TEXT NOT NULL,
    SocialAction TEXT NOT NULL,
    HTTPError SMALLINT NOT NULL,
    SendTiming INTEGER NOT NULL,
    DNSTiming INTEGER NOT NULL,
    ConnectTiming INTEGER NOT NULL,
    ResponseStartTiming INTEGER NOT NULL,
    ResponseEndTiming INTEGER NOT NULL,
    FetchTiming INTEGER NOT NULL,
    SocialSourceNetworkID SMALLINT NOT NULL,
    SocialSourcePage TEXT NOT NULL,
    ParamPrice BIGINT NOT NULL,
    ParamOrderID TEXT NOT NULL,
    ParamCurrency TEXT NOT NULL,
    ParamCurrencyID SMALLINT NOT NULL,
    OpenstatServiceName TEXT NOT NULL,
    OpenstatCampaignID TEXT NOT NULL,
    OpenstatAdID TEXT NOT NULL,
    OpenstatSourceID TEXT NOT NULL,
    UTMSource TEXT NOT NULL,
    UTMMedium TEXT NOT NULL,
    UTMCampaign TEXT NOT NULL,
    UTMContent TEXT NOT NULL,
    UTMTerm TEXT NOT NULL,
    FromTag TEXT NOT NULL,
    HasGCLID SMALLINT NOT NULL,
    RefererHash BIGINT NOT NULL,
    URLHash BIGINT NOT NULL,
    CLID INTEGER NOT NULL,
    PRIMARY KEY (id)
)
ENGINE = MergeTree
SETTINGS fsync_after_insert = 1, auto_statistics_types = '';

CREATE OR REPLACE TABLE hits_WatchID (id BIGINT NOT NULL, WatchID BIGINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_JavaEnable (id BIGINT NOT NULL, JavaEnable SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_Title (id BIGINT NOT NULL, Title TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_GoodEvent (id BIGINT NOT NULL, GoodEvent SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_EventTime (id BIGINT NOT NULL, EventTime TIMESTAMP NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_EventDate (id BIGINT NOT NULL, EventDate Date NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_CounterID (id BIGINT NOT NULL, CounterID INTEGER NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_ClientIP (id BIGINT NOT NULL, ClientIP INTEGER NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_RegionID (id BIGINT NOT NULL, RegionID INTEGER NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_UserID (id BIGINT NOT NULL, UserID BIGINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_CounterClass (id BIGINT NOT NULL, CounterClass SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_OS (id BIGINT NOT NULL, OS SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_UserAgent (id BIGINT NOT NULL, UserAgent SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_URL (id BIGINT NOT NULL, URL TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_Referer (id BIGINT NOT NULL, Referer TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_IsRefresh (id BIGINT NOT NULL, IsRefresh SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_RefererCategoryID (id BIGINT NOT NULL, RefererCategoryID SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_RefererRegionID (id BIGINT NOT NULL, RefererRegionID INTEGER NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_URLCategoryID (id BIGINT NOT NULL, URLCategoryID SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_URLRegionID (id BIGINT NOT NULL, URLRegionID INTEGER NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_ResolutionWidth (id BIGINT NOT NULL, ResolutionWidth SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_ResolutionHeight (id BIGINT NOT NULL, ResolutionHeight SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_ResolutionDepth (id BIGINT NOT NULL, ResolutionDepth SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_FlashMajor (id BIGINT NOT NULL, FlashMajor SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_FlashMinor (id BIGINT NOT NULL, FlashMinor SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_FlashMinor2 (id BIGINT NOT NULL, FlashMinor2 TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_NetMajor (id BIGINT NOT NULL, NetMajor SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_NetMinor (id BIGINT NOT NULL, NetMinor SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_UserAgentMajor (id BIGINT NOT NULL, UserAgentMajor SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_UserAgentMinor (id BIGINT NOT NULL, UserAgentMinor VARCHAR(255) NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_CookieEnable (id BIGINT NOT NULL, CookieEnable SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_JavascriptEnable (id BIGINT NOT NULL, JavascriptEnable SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_IsMobile (id BIGINT NOT NULL, IsMobile SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_MobilePhone (id BIGINT NOT NULL, MobilePhone SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_MobilePhoneModel (id BIGINT NOT NULL, MobilePhoneModel TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_Params (id BIGINT NOT NULL, Params TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_IPNetworkID (id BIGINT NOT NULL, IPNetworkID INTEGER NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_TraficSourceID (id BIGINT NOT NULL, TraficSourceID SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_SearchEngineID (id BIGINT NOT NULL, SearchEngineID SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_SearchPhrase (id BIGINT NOT NULL, SearchPhrase TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_AdvEngineID (id BIGINT NOT NULL, AdvEngineID SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_IsArtifical (id BIGINT NOT NULL, IsArtifical SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_WindowClientWidth (id BIGINT NOT NULL, WindowClientWidth SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_WindowClientHeight (id BIGINT NOT NULL, WindowClientHeight SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_ClientTimeZone (id BIGINT NOT NULL, ClientTimeZone SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_ClientEventTime (id BIGINT NOT NULL, ClientEventTime TIMESTAMP NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_SilverlightVersion1 (id BIGINT NOT NULL, SilverlightVersion1 SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_SilverlightVersion2 (id BIGINT NOT NULL, SilverlightVersion2 SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_SilverlightVersion3 (id BIGINT NOT NULL, SilverlightVersion3 INTEGER NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_SilverlightVersion4 (id BIGINT NOT NULL, SilverlightVersion4 SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_PageCharset (id BIGINT NOT NULL, PageCharset TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_CodeVersion (id BIGINT NOT NULL, CodeVersion INTEGER NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_IsLink (id BIGINT NOT NULL, IsLink SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_IsDownload (id BIGINT NOT NULL, IsDownload SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_IsNotBounce (id BIGINT NOT NULL, IsNotBounce SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_FUniqID (id BIGINT NOT NULL, FUniqID BIGINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_OriginalURL (id BIGINT NOT NULL, OriginalURL TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_HID (id BIGINT NOT NULL, HID INTEGER NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_IsOldCounter (id BIGINT NOT NULL, IsOldCounter SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_IsEvent (id BIGINT NOT NULL, IsEvent SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_IsParameter (id BIGINT NOT NULL, IsParameter SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_DontCountHits (id BIGINT NOT NULL, DontCountHits SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_WithHash (id BIGINT NOT NULL, WithHash SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_HitColor (id BIGINT NOT NULL, HitColor CHAR NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_LocalEventTime (id BIGINT NOT NULL, LocalEventTime TIMESTAMP NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_Age (id BIGINT NOT NULL, Age SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_Sex (id BIGINT NOT NULL, Sex SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_Income (id BIGINT NOT NULL, Income SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_Interests (id BIGINT NOT NULL, Interests SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_Robotness (id BIGINT NOT NULL, Robotness SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_RemoteIP (id BIGINT NOT NULL, RemoteIP INTEGER NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_WindowName (id BIGINT NOT NULL, WindowName INTEGER NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_OpenerName (id BIGINT NOT NULL, OpenerName INTEGER NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_HistoryLength (id BIGINT NOT NULL, HistoryLength SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_BrowserLanguage (id BIGINT NOT NULL, BrowserLanguage TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_BrowserCountry (id BIGINT NOT NULL, BrowserCountry TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_SocialNetwork (id BIGINT NOT NULL, SocialNetwork TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_SocialAction (id BIGINT NOT NULL, SocialAction TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_HTTPError (id BIGINT NOT NULL, HTTPError SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_SendTiming (id BIGINT NOT NULL, SendTiming INTEGER NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_DNSTiming (id BIGINT NOT NULL, DNSTiming INTEGER NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_ConnectTiming (id BIGINT NOT NULL, ConnectTiming INTEGER NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_ResponseStartTiming (id BIGINT NOT NULL, ResponseStartTiming INTEGER NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_ResponseEndTiming (id BIGINT NOT NULL, ResponseEndTiming INTEGER NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_FetchTiming (id BIGINT NOT NULL, FetchTiming INTEGER NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_SocialSourceNetworkID (id BIGINT NOT NULL, SocialSourceNetworkID SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_SocialSourcePage (id BIGINT NOT NULL, SocialSourcePage TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_ParamPrice (id BIGINT NOT NULL, ParamPrice BIGINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_ParamOrderID (id BIGINT NOT NULL, ParamOrderID TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_ParamCurrency (id BIGINT NOT NULL, ParamCurrency TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_ParamCurrencyID (id BIGINT NOT NULL, ParamCurrencyID SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_OpenstatServiceName (id BIGINT NOT NULL, OpenstatServiceName TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_OpenstatCampaignID (id BIGINT NOT NULL, OpenstatCampaignID TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_OpenstatAdID (id BIGINT NOT NULL, OpenstatAdID TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_OpenstatSourceID (id BIGINT NOT NULL, OpenstatSourceID TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_UTMSource (id BIGINT NOT NULL, UTMSource TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_UTMMedium (id BIGINT NOT NULL, UTMMedium TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_UTMCampaign (id BIGINT NOT NULL, UTMCampaign TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_UTMContent (id BIGINT NOT NULL, UTMContent TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_UTMTerm (id BIGINT NOT NULL, UTMTerm TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_FromTag (id BIGINT NOT NULL, FromTag TEXT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_HasGCLID (id BIGINT NOT NULL, HasGCLID SMALLINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_RefererHash (id BIGINT NOT NULL, RefererHash BIGINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_URLHash (id BIGINT NOT NULL, URLHash BIGINT NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';
CREATE OR REPLACE TABLE hits_CLID (id BIGINT NOT NULL, CLID INTEGER NOT NULL, PRIMARY KEY (id)) ENGINE = MergeTree SETTINGS fsync_after_insert = 1, auto_statistics_types = '';

CREATE OR REPLACE VIEW hits AS
SELECT
    WatchID,
    JavaEnable,
    Title,
    GoodEvent,
    EventTime,
    EventDate,
    CounterID,
    ClientIP,
    RegionID,
    UserID,
    CounterClass,
    OS,
    UserAgent,
    URL,
    Referer,
    IsRefresh,
    RefererCategoryID,
    RefererRegionID,
    URLCategoryID,
    URLRegionID,
    ResolutionWidth,
    ResolutionHeight,
    ResolutionDepth,
    FlashMajor,
    FlashMinor,
    FlashMinor2,
    NetMajor,
    NetMinor,
    UserAgentMajor,
    UserAgentMinor,
    CookieEnable,
    JavascriptEnable,
    IsMobile,
    MobilePhone,
    MobilePhoneModel,
    Params,
    IPNetworkID,
    TraficSourceID,
    SearchEngineID,
    SearchPhrase,
    AdvEngineID,
    IsArtifical,
    WindowClientWidth,
    WindowClientHeight,
    ClientTimeZone,
    ClientEventTime,
    SilverlightVersion1,
    SilverlightVersion2,
    SilverlightVersion3,
    SilverlightVersion4,
    PageCharset,
    CodeVersion,
    IsLink,
    IsDownload,
    IsNotBounce,
    FUniqID,
    OriginalURL,
    HID,
    IsOldCounter,
    IsEvent,
    IsParameter,
    DontCountHits,
    WithHash,
    HitColor,
    LocalEventTime,
    Age,
    Sex,
    Income,
    Interests,
    Robotness,
    RemoteIP,
    WindowName,
    OpenerName,
    HistoryLength,
    BrowserLanguage,
    BrowserCountry,
    SocialNetwork,
    SocialAction,
    HTTPError,
    SendTiming,
    DNSTiming,
    ConnectTiming,
    ResponseStartTiming,
    ResponseEndTiming,
    FetchTiming,
    SocialSourceNetworkID,
    SocialSourcePage,
    ParamPrice,
    ParamOrderID,
    ParamCurrency,
    ParamCurrencyID,
    OpenstatServiceName,
    OpenstatCampaignID,
    OpenstatAdID,
    OpenstatSourceID,
    UTMSource,
    UTMMedium,
    UTMCampaign,
    UTMContent,
    UTMTerm,
    FromTag,
    HasGCLID,
    RefererHash,
    URLHash,
    CLID
FROM hits_WatchID
JOIN hits_JavaEnable USING (id)
JOIN hits_Title USING (id)
JOIN hits_GoodEvent USING (id)
JOIN hits_EventTime USING (id)
JOIN hits_EventDate USING (id)
JOIN hits_CounterID USING (id)
JOIN hits_ClientIP USING (id)
JOIN hits_RegionID USING (id)
JOIN hits_UserID USING (id)
JOIN hits_CounterClass USING (id)
JOIN hits_OS USING (id)
JOIN hits_UserAgent USING (id)
JOIN hits_URL USING (id)
JOIN hits_Referer USING (id)
JOIN hits_IsRefresh USING (id)
JOIN hits_RefererCategoryID USING (id)
JOIN hits_RefererRegionID USING (id)
JOIN hits_URLCategoryID USING (id)
JOIN hits_URLRegionID USING (id)
JOIN hits_ResolutionWidth USING (id)
JOIN hits_ResolutionHeight USING (id)
JOIN hits_ResolutionDepth USING (id)
JOIN hits_FlashMajor USING (id)
JOIN hits_FlashMinor USING (id)
JOIN hits_FlashMinor2 USING (id)
JOIN hits_NetMajor USING (id)
JOIN hits_NetMinor USING (id)
JOIN hits_UserAgentMajor USING (id)
JOIN hits_UserAgentMinor USING (id)
JOIN hits_CookieEnable USING (id)
JOIN hits_JavascriptEnable USING (id)
JOIN hits_IsMobile USING (id)
JOIN hits_MobilePhone USING (id)
JOIN hits_MobilePhoneModel USING (id)
JOIN hits_Params USING (id)
JOIN hits_IPNetworkID USING (id)
JOIN hits_TraficSourceID USING (id)
JOIN hits_SearchEngineID USING (id)
JOIN hits_SearchPhrase USING (id)
JOIN hits_AdvEngineID USING (id)
JOIN hits_IsArtifical USING (id)
JOIN hits_WindowClientWidth USING (id)
JOIN hits_WindowClientHeight USING (id)
JOIN hits_ClientTimeZone USING (id)
JOIN hits_ClientEventTime USING (id)
JOIN hits_SilverlightVersion1 USING (id)
JOIN hits_SilverlightVersion2 USING (id)
JOIN hits_SilverlightVersion3 USING (id)
JOIN hits_SilverlightVersion4 USING (id)
JOIN hits_PageCharset USING (id)
JOIN hits_CodeVersion USING (id)
JOIN hits_IsLink USING (id)
JOIN hits_IsDownload USING (id)
JOIN hits_IsNotBounce USING (id)
JOIN hits_FUniqID USING (id)
JOIN hits_OriginalURL USING (id)
JOIN hits_HID USING (id)
JOIN hits_IsOldCounter USING (id)
JOIN hits_IsEvent USING (id)
JOIN hits_IsParameter USING (id)
JOIN hits_DontCountHits USING (id)
JOIN hits_WithHash USING (id)
JOIN hits_HitColor USING (id)
JOIN hits_LocalEventTime USING (id)
JOIN hits_Age USING (id)
JOIN hits_Sex USING (id)
JOIN hits_Income USING (id)
JOIN hits_Interests USING (id)
JOIN hits_Robotness USING (id)
JOIN hits_RemoteIP USING (id)
JOIN hits_WindowName USING (id)
JOIN hits_OpenerName USING (id)
JOIN hits_HistoryLength USING (id)
JOIN hits_BrowserLanguage USING (id)
JOIN hits_BrowserCountry USING (id)
JOIN hits_SocialNetwork USING (id)
JOIN hits_SocialAction USING (id)
JOIN hits_HTTPError USING (id)
JOIN hits_SendTiming USING (id)
JOIN hits_DNSTiming USING (id)
JOIN hits_ConnectTiming USING (id)
JOIN hits_ResponseStartTiming USING (id)
JOIN hits_ResponseEndTiming USING (id)
JOIN hits_FetchTiming USING (id)
JOIN hits_SocialSourceNetworkID USING (id)
JOIN hits_SocialSourcePage USING (id)
JOIN hits_ParamPrice USING (id)
JOIN hits_ParamOrderID USING (id)
JOIN hits_ParamCurrency USING (id)
JOIN hits_ParamCurrencyID USING (id)
JOIN hits_OpenstatServiceName USING (id)
JOIN hits_OpenstatCampaignID USING (id)
JOIN hits_OpenstatAdID USING (id)
JOIN hits_OpenstatSourceID USING (id)
JOIN hits_UTMSource USING (id)
JOIN hits_UTMMedium USING (id)
JOIN hits_UTMCampaign USING (id)
JOIN hits_UTMContent USING (id)
JOIN hits_UTMTerm USING (id)
JOIN hits_FromTag USING (id)
JOIN hits_HasGCLID USING (id)
JOIN hits_RefererHash USING (id)
JOIN hits_URLHash USING (id)
JOIN hits_CLID USING (id);
