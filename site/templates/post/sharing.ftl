<div class="sharing">
  <#if (site.twitter_tweet_button)!false == true>
  <#assign showTweetButton = true>
  <a href="http://twitter.com/share" class="twitter-share-button" data-url="${ site.url }${ page.url }" data-via="${ site.twitter_user }" data-counturl="${ site.url }${ page.url }" >Tweet</a>
  </#if>
  <#if (site.google_plus_one)!false == true>
  <#assign showGooglePlusOne = true>
  <div class="g-plusone" data-size="${ site.google_plus_one_size }"></div>
  </#if>
  <#if (site.facebook_like)!false == true>
  <#assign showFacebookLike = true>
    <div class="fb-like" data-send="true" data-width="450" data-show-faces="false"></div>
  </#if>

<!-- sharebar button begin -->
<div class="bdsharebuttonbox"><a href="#" class="bds_more" data-cmd="more"></a><a title="分享到豆瓣网" href="#" class="bds_douban" data-cmd="douban"></a><a title="分享到新浪微博" href="#" class="bds_tsina" data-cmd="tsina"></a><a title="分享到腾讯微博" href="#" class="bds_tqq" data-cmd="tqq"></a><a title="分享到网易微博" href="#" class="bds_t163" data-cmd="t163"></a><a title="分享到有道云笔记" href="#" class="bds_youdao" data-cmd="youdao"></a><a title="分享到Facebook" href="#" class="bds_fbook" data-cmd="fbook"></a><a title="分享到delicious" href="#" class="bds_deli" data-cmd="deli"></a><a title="分享到Twitter" href="#" class="bds_twi" data-cmd="twi"></a><a title="分享到打印" href="#" class="bds_print" data-cmd="print"></a><a title="分享到复制网址" href="#" class="bds_copy" data-cmd="copy"></a></div>
<script>window._bd_share_config={"common":{"bdSnsKey":{},"bdText":"","bdMini":"2","bdMiniList":false,"bdPic":"","bdStyle":"1","bdSize":"16"},"share":{},"image":{"viewList":["douban","tsina","tqq","t163","youdao","fbook","deli","twi","print","copy"],"viewText":"分享到：","viewSize":"16"},"selectShare":{"bdContainerClass":null,"bdSelectMiniList":false}};with(document)0[(getElementsByTagName('head')[0]||body).appendChild(createElement('script')).src='http://bdimg.share.baidu.com/static/api/js/share.js?v=86326610.js?cdnversion='+~(-new Date()/36e5)];</script>
<!-- sharebar button end -->

</div>
