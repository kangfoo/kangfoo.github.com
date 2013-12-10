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
<a class="sharebar_button_douban"></a>
<div class="sharebar_toolbox">
<a class="sharebar_button_tsina"></a>
<a class="sharebar_button_kaixin001"></a>
<a class="sharebar_button_renren"></a>
<span class="sharebar_separator">|</span>
<a href="http://www.sharebar.cn/" class="sharebar_button_compact">更多</a>
</div>
<script type="text/javascript" src="http://s.sharebar.cn/js/sharebar_button.js" charset="utf-8"></script>
<!-- sharebar button end -->

</div>
