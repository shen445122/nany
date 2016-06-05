import urllib.request
import json
send_headers = {
    'Accept':'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    #'Accept-Encoding':'gzip, deflate, sdch',
    #'Accept-Language':'zh-CN,zh;q=0.8,en;q=0.6',
    'Cache-Control':'max-age=0',
    'Connection':'keep-alive',
    'Cookie':'s=1wos19yvy4; xq_a_token=e091ebfe5ded576016d5799ac18315a69336a5bd; xq_r_token=9881106dea309c7184d4b85b6f56068f266e1c9c; __utma=1.1116224111.1463218990.1465126252.1465129340.11; __utmb=1.4.10.1465129340; __utmc=1; __utmz=1.1463317695.3.2.utmcsr=google|utmccn=(organic)|utmcmd=organic|utmctr=(not%20provided); Hm_lvt_1db88642e346389874251b5a1eded6e3=1463317428,1463317695,1463909186,1465126236; Hm_lpvt_1db88642e346389874251b5a1eded6e3=1465130565',
    'Host':'xueqiu.com',
    #'Upgrade-Insecure-Requests':'1',
    'User-Agent':'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/50.0.2661.102 Safari/537.36'
}

url = 'https://xueqiu.com/S/SH600697'
req = urllib.request.Request(url,headers=send_headers)
html = urllib.request.urlopen(req).read().decode('utf-8')
#print(html)

pos_start = html.find('SNB.data.quote = ') + len('SNB.data.quote = ')
pos_end = html.find('seajs.use(["SNB.') - 2
data = html[pos_start:pos_end]
#print(data)
#print(pos_start,pos_end)
dic = json.loads(data)
print(dic["open"])
