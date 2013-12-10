<fieldset class="mobile-nav">
  <select onchange="if (this.value) { window.location.href = this.value;}">
    <option value=""><@i18n.msg "Navigate"/>&hellip;</option>
    <#list site.navs?keys as navLabel>
    <#assign navUrl = site.navs[navLabel]>
    <option value="${navUrl}"<#if (root_url + page.url) == navUrl> selected="selected"</#if>>&raquo; ${navLabel}</option>

    <#-- 插在首页之后 -->
    <#if navUrl == '/' && site.categories?? &&  (site.categories?size > 0)>
    <#list site.categories as category>
    <option value="${root_url}${category.url}"<#if page.url == category.url> selected="selected"</#if>>&raquo; ${category.name}</option>
    </#list>
    </#if>

    </#list>
  </select>
</fieldset>

<ul class="main-navigation">
<#list site.navs?keys as navLabel>
<li><a href="${site.navs[navLabel]}"<#if site.navs[navLabel]?starts_with("http")> target="_blank"</#if>>${navLabel}</a></li>
<#-- 插在首页之后 -->
<#if site.navs[navLabel] == '/' && site.categories?? &&  (site.categories?size > 0)>
<#list site.categories as category>
<li><a href="${root_url}${category.url}">${category.name}</a></li>
</#list>
</#if>
</#list>
</ul>
