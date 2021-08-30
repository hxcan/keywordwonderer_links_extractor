#!/usr/bin/env ruby

# require 'em/pure_ruby'
require 'eventmachine'
require 'websocket-eventmachine-client'
require 'QWebChannel' #自行移植的QWebChannel库
require 'nokogiri' #Nokogiri XML库。

$webChannelApiObject={}

#处理事件，需要解析网页中的链接。
$processNeedExtractLinksEvent = Proc.new do |text, isFinalResult|
    #解析链接，并回复：
    xmlDoc=Nokogiri::HTML(text) #构造HTML文档对象。

    #链接列表：
    hrefList=[] #链接地址列表。
    
    aList=xmlDoc.css("a") #找到链接元素。
    aList.each do |currentImg| #一个个链接元素地处理。
        print("Href: #{currentImg['href']}\n") #Debug.
#       currentImg['style']='' #去掉样式。
        
        hrefList << currentImg['href'] #加入到列表中。
    end #aList.each do |currentImg| #一个个图片元素地处理。
    
    #图片列表：
    srcList=[] #图片地址列表。
    
    imgList=xmlDoc.css("img") #找到链接元素。
    imgList.each do |currentImg| #一个个链接元素地处理。
        print("Src: #{currentImg['src']}\n") #Debug.
#       currentImg['style']='' #去掉样式。
        
        srcList << currentImg['src'] #加入到列表中。
    end #aList.each do |currentImg| #一个个图片元素地处理。

    #构造JSON，并且回复：
    jsonObject={} #用于格式化JSON的对象。
    jsonObject['urls']=hrefList #赋值属性，网址列表。
    jsonObject['imgs']=srcList #赋值属性，图片列表。
    
    jsnWhlStr=Oj.dump(jsonObject) #格式化成JSON。

    $webChannelApiObject.reportLinks(jsnWhlStr, isFinalResult) #报告链接列表。
end #$showVoiceRecognizedEvent = Proc.new do |text, isFinalResult|

#此函数用于向C++ QT端报告本进程已经准备好了。
$readyReportProc = Proc.new do
    $webChannelApiObject.reportLinksExtractorReady() #报告，链接提取者已经准备好。
end #$showFaceRecognizeResultEvent = Proc.new do |messageContent|

EM.run do
    ws = WebSocket::EventMachine::Client.connect(:uri => 'ws://127.0.0.1:16391') #连接网页套接字。

    ws.onopen do #连接上了WebSocket
        puts "Connected to websocket" #Debug.
        
        qWebChannel = QWebChannel.new(ws) do |channel|
            $webChannelApiObject=channel.objects['apiObject']
            
            puts "Connected to WebChannel, ready to send/receive messages!"
            
            $webChannelApiObject['needExtractLinksEvent'].connect($processNeedExtractLinksEvent) #收到网页内容解析请求，则对应处理。

            $readyReportProc.call #报告准备完毕。
        end
    end #ws.onopen do #连接上了WebSocket

    ws.onclose do |code, reason|
        puts "Disconnected with status code: #{code}"
        EM.stop
    end
end
