=begin
# install yaz http://www.indexdata.dk/yaz/ : 
#     ./configure --enable-shared
#     make
#     sudo make install
#
# install ruby/zoom http://ruby-zoom.rubyforge.org/ : 
#     ruby extconf.rg
#     make
#     sudo make install

asin = '0521780195'
book_covers = '/Users/gaspard/book_covers/'
#asin = '0226732169'
#asin = '023945857892' # bad for testing

#require 'zoom' 
#
#ZOOM::Connection.open('z3950.loc.gov', 7090) do |conn|
#  conn.database_name = 'Voyager'
#  conn.preferred_record_syntax = 'USMARC'
#  rset = conn.search("@attr 1=7 #{asin}")
#  p rset[0]
#end

# using amazon web services :
# access key : 1186KA3K523YWH49MV02
# US : http://webservices.amazon.com/onca/xml?Service=AWSECommerceService&AWSAccessKeyId=1186KA3K523YWH49MV02&Operation=ItemLookup&IdType=ASIN&ItemId=#{asin}&MerchantId=All&ResponseGroup=Large

require 'net/http' # http://www.ruby-doc.org/stdlib/libdoc/net/http/rdoc/
url = "http://webservices.amazon.com/onca/xml?Service=AWSECommerceService&AWSAccessKeyId=1186KA3K523YWH49MV02&Operation=ItemLookup&IdType=ASIN&ItemId=#{asin}&MerchantId=All&ResponseGroup=Medium"
r = Net::HTTP.get_response( URI.parse( url ) )

# parse xml
require "rexml/document"
include REXML

doc = REXML::Document.new r.body
# error handling
doc.elements.each("ItemLookupResponse/Items/Request/Errors/Error/Message") {|elem| puts elem.text}

# get book info
puts doc.elements["ItemLookupResponse/Items/Item/ItemAttributes/Title"].text
puts doc.elements["ItemLookupResponse/Items/Item/ItemAttributes/Author"].text
#doc.elements.each("ItemLookupResponse/Items/Item/ItemAttributes/Author") {|elem| puts elem.text}
puts doc.elements["ItemLookupResponse/Items/Item/ItemAttributes/NumberOfPages"].text
puts doc.elements["ItemLookupResponse/Items/Item/ItemAttributes/ProductGroup"].text
puts doc.elements["ItemLookupResponse/Items/Item/ItemAttributes/PublicationDate"].text
puts doc.elements["ItemLookupResponse/Items/Item/ItemAttributes/Publisher"].text
# size in cm :
puts doc.elements["ItemLookupResponse/Items/Item/ItemAttributes/PackageDimensions/Length"].text.to_f * 0.0254
puts doc.elements["ItemLookupResponse/Items/Item/ItemAttributes/PackageDimensions/Width"].text.to_f * 0.0254
puts doc.elements["ItemLookupResponse/Items/Item/ItemAttributes/PackageDimensions/Height"].text.to_f * 0.0254
puts doc.elements["ItemLookupResponse/Items/Item/ItemAttributes/PackageDimensions/Weight"].text.to_f * 4.54

# detail page
puts doc.elements["ItemLookupResponse/Items/Item/DetailPageURL"].text

# get cover pictures

def getCover(asin,url,size,local_folder)
  filename = "#{local_folder}#{size}_#{asin}.jpg"
  if File.exist?(filename)
    puts "#{filename} exists."
  else
    puts "downloading #{url}... to #{filename}"
    # download pict
    pict = Net::HTTP.get_response(URI.parse(url))
    File.open(filename, 'wb') {|f| f.write(pict.body)}
  end
end
getCover(asin,doc.elements["ItemLookupResponse/Items/Item/SmallImage/URL"].text,'Small',book_covers)
getCover(asin,doc.elements["ItemLookupResponse/Items/Item/MediumImage/URL"].text,'Medium',book_covers)
getCover(asin,doc.elements["ItemLookupResponse/Items/Item/LargeImage/URL"].text,'Large',book_covers)
=end
=begin
<?xml version="1.0" encoding="UTF-8"?>
<ItemLookupResponse xmlns="http://webservices.amazon.com/AWSECommerceService/2005-10-05">
	<OperationRequest>
		<HTTPHeaders>
			<Header Name="UserAgent" Value="curl/7.13.1 (powerpc-apple-darwin8.0) libcurl/7.13.1 OpenSSL/0.9.7i zlib/1.2.3"/>
		</HTTPHeaders>
		<RequestId>1FNX6CR1RERFCW0804E1</RequestId>
		<Arguments>
			<Argument Name="ResponseGroup" Value="Medium"/>
			<Argument Name="Operation" Value="ItemLookup"/>
			<Argument Name="MerchantId" Value="All"/>
			<Argument Name="Service" Value="AWSECommerceService"/>
			<Argument Name="AWSAccessKeyId" Value="1186KA3K523YWH49MV02"/>
			<Argument Name="ItemId" Value="097669400X"/>
			<Argument Name="IdType" Value="ASIN"/>
		</Arguments>
		<RequestProcessingTime>0.0330460071563721</RequestProcessingTime>
	</OperationRequest>
	<Items>
		<Request>
			<IsValid>True</IsValid>
			<ItemLookupRequest>
				<IdType>ASIN</IdType>
				<MerchantId>All</MerchantId>
				<ItemId>097669400X</ItemId>
				<ResponseGroup>Medium</ResponseGroup>
			</ItemLookupRequest>
		</Request>
		<Item>
			<ASIN>097669400X</ASIN>
			<DetailPageURL>http://www.amazon.com/exec/obidos/redirect?tag=ws%26link_code=xm2%26camp=2025%26creative=165953%26path=http://www.amazon.com/gp/redirect.html%253fASIN=097669400X%2526tag=ws%2526lcode=xm2%2526cID=2025%2526ccmID=165953%2526location=/o/ASIN/097669400X%25253FSubscriptionId=1186KA3K523YWH49MV02</DetailPageURL>
			<SalesRank>656</SalesRank>
			<SmallImage>
				<URL>http://images.amazon.com/images/P/097669400X.01._SCTHUMBZZZ_.jpg</URL>
				<Height Units="pixels">75</Height>
				<Width Units="pixels">62</Width>
			</SmallImage>
			<MediumImage>
				<URL>http://images.amazon.com/images/P/097669400X.01._SCMZZZZZZZ_.jpg</URL>
				<Height Units="pixels">160</Height>
				<Width Units="pixels">133</Width>
			</MediumImage>
			<LargeImage>
				<URL>http://images.amazon.com/images/P/097669400X.01._SCLZZZZZZZ_.jpg</URL>
				<Height Units="pixels">500</Height>
				<Width Units="pixels">416</Width>
			</LargeImage>
			<ImageSets>
				<ImageSet Category="primary">
					<SmallImage>
						<URL>http://images.amazon.com/images/P/097669400X.01._SCTHUMBZZZ_.jpg</URL>
						<Height Units="pixels">75</Height>
						<Width Units="pixels">62</Width>
					</SmallImage>
					<MediumImage>
						<URL>http://images.amazon.com/images/P/097669400X.01._SCMZZZZZZZ_.jpg</URL>
						<Height Units="pixels">160</Height>
						<Width Units="pixels">133</Width>
					</MediumImage>
					<LargeImage>
						<URL>http://images.amazon.com/images/P/097669400X.01._SCLZZZZZZZ_.jpg</URL>
						<Height Units="pixels">500</Height>
						<Width Units="pixels">416</Width>
					</LargeImage>
				</ImageSet>
			</ImageSets>
			<ItemAttributes>
				<Author>Dave Thomas</Author>
				<Author>David Hansson</Author>
				<Author>Leon Breedt</Author>
				<Author>Mike Clark</Author>
				<Author>Thomas Fuchs</Author>
				<Author>Andrea Schwarz</Author>
				<Binding>Paperback</Binding>
				<EAN>9780976694007</EAN>
				<Edition>1</Edition>
				<ISBN>097669400X</ISBN>
				<ListPrice>
					<Amount>3495</Amount>
					<CurrencyCode>USD</CurrencyCode>
					<FormattedPrice>$34.95</FormattedPrice>
				</ListPrice>
				<NumberOfItems>1</NumberOfItems>
				<NumberOfPages>450</NumberOfPages>
				<PackageDimensions>
					<Height Units="hundredths-inches">105</Height>
					<Length Units="hundredths-inches">900</Length>
					<Weight Units="hundredths-pounds">187</Weight>
					<Width Units="hundredths-inches">750</Width>
				</PackageDimensions>
				<ProductGroup>Book</ProductGroup>
				<PublicationDate>2005-07-01</PublicationDate>
				<Publisher>Pragmatic Bookshelf</Publisher>
				<Title>Agile Web Development with Rails : A Pragmatic Guide (The Facets of Ruby Series)</Title>
			</ItemAttributes>
			<OfferSummary>
				<LowestNewPrice>
					<Amount>2276</Amount>
					<CurrencyCode>USD</CurrencyCode>
					<FormattedPrice>$22.76</FormattedPrice>
				</LowestNewPrice>
				<LowestUsedPrice>
					<Amount>2276</Amount>
					<CurrencyCode>USD</CurrencyCode>
					<FormattedPrice>$22.76</FormattedPrice>
				</LowestUsedPrice>
				<LowestCollectiblePrice>
					<Amount>3495</Amount>
					<CurrencyCode>USD</CurrencyCode>
					<FormattedPrice>$34.95</FormattedPrice>
				</LowestCollectiblePrice>
				<TotalNew>25</TotalNew>
				<TotalUsed>9</TotalUsed>
				<TotalCollectible>1</TotalCollectible>
				<TotalRefurbished>0</TotalRefurbished>
			</OfferSummary>
			<EditorialReviews>
				<EditorialReview>
					<Source>Book Description</Source>
					<Content>Rails is a full-stack, open-source web framework that enables you to create full-featured, sophisticated web-based applications, but with a twist... A full Rails application probably has less total code than the XML you'd need to configure the same application in other frameworks.    With this book you'll learn how to use &lt;i&gt;ActiveRecord&lt;/i&gt; to connect business objects and database tables.  No more painful object-relational mapping.  Just create your business objects and let Rails do the rest.  You'll learn how to use the &lt;i&gt;Action Pack&lt;/i&gt; framework to route incoming requests and render pages using easy-to-write templates and components. See how to exploit the Rails service frameworks to send emails, implement web services, and create dynamic, user-centric web-pages using built-in Javascript and Ajax support. There are extensive chapters on testing, deployment, and scaling.    You'll see how easy it is to install Rails using your web server of choice (such as Apache or lighttpd) or using its own included web server.  You'll be writing applications that work with your favorite database (MySQL, Oracle, Postgres, and more) in no time at all.    You'll create a complete online store application in the extended tutorial section, so you'll see how a full Rails application is developed---iteratively and rapidly.    Rails strives to honor the Pragmatic Programmer's "DRY Principle" by avoiding the extra work of configuration files and code annotations.  You can develop in real-time: make a change, and watch it work immediately.    Forget XML.  Everything in Rails, from templates to control flow to business logic, is written in Ruby, the language of choice for programmers who like to get the job done well (and leave work on time for a change).    Rails is the framework of choice for the new generation of Web 2.0 developers. &lt;em&gt;Agile Web Development with   Rails&lt;/em&gt; is the book for that generation, written by Dave Thomas (Pragmatic Programmer and author of &lt;em&gt;Programming Ruby&lt;/em&gt;) and David Heinemeier Hansson, who created Rails.</Content>
				</EditorialReview>
			</EditorialReviews>
		</Item>
	</Items>
</ItemLookupResponse>
=end


=begin
<?xml version="1.0" encoding="UTF-8"?>
<ItemLookupResponse xmlns="http://webservices.amazon.com/AWSECommerceService/2005-10-05">
	<OperationRequest>
		<HTTPHeaders>
			<Header Name="UserAgent" Value="Mozilla/5.0 (Macintosh; U; PPC Mac OS X; fr) AppleWebKit/416.11 (KHTML, like Gecko) Safari/416.12"/>
		</HTTPHeaders>
		<RequestId>1A8ACWG822D5K6X4HS5C</RequestId>
		<Arguments>
			<Argument Name="MerchantId" Value="All"/>
			<Argument Name="Service" Value="AWSECommerceService"/>
			<Argument Name="AWSAccessKeyId" Value="1186KA3K523YWH49MV02"/>
			<Argument Name="ItemId" Value="0976698746400X"/>
			<Argument Name="IdType" Value="ASIN"/>
			<Argument Name="ResponseGroup" Value="Medium"/>
			<Argument Name="Operation" Value="ItemLookup"/>
		</Arguments>
		<RequestProcessingTime>0.0273139476776123</RequestProcessingTime>
	</OperationRequest>
	<Items>
		<Request>
			<IsValid>True</IsValid>
			<ItemLookupRequest>
				<IdType>ASIN</IdType>
				<MerchantId>All</MerchantId>
				<ItemId>0976698746400X</ItemId>
				<ResponseGroup>Medium</ResponseGroup>
			</ItemLookupRequest>
			<Errors>
				<Error>
					<Code>AWS.InvalidParameterValue</Code>
					<Message>0976698746400X is not a valid value for ItemId. Please change this value and retry your request.</Message>
				</Error>
			</Errors>
		</Request>
	</Items>
</ItemLookupResponse>
=end
