require 'test_helper'

class UploadTest < Zena::View::TestCase
  include Zena::Use::Upload::ControllerMethods
  attr_reader :params

  # only run these tests if network is available
  if Zena::Use::Upload.has_network?
    context 'Uploading with an attachment url' do
      setup do
        @params = {'attachment_url' => 'http://zenadmin.org/fr/blog/image5.jpg'}
      end

      should 'provide a file with the downloaded content' do
        file, error = get_attachment
        assert file, "error: #{error}"
        content = file.read
        assert_equal 73633, content.size
      end

      context 'to a file too large' do
        setup do
          #@params = {'attachment_url' => 'http://apod.nasa.gov/apod/image/0901/gcenter_hstspitzer_big.jpg'}
          @params = {'attachment_url' => 'http://upload.wikimedia.org/wikipedia/commons/f/f4/360-degree_Panorama_of_the_Southern_Sky.jpg'}
        end

        should 'return an error about file being too big, without a download' do
          file, error = get_attachment
          assert_nil file
          assert_equal 'size (18 MB) too big to fetch url', error
        end
      end

      context 'to a file without size' do
        setup do
          @params = {'attachment_url' => "http://prdownload.berlios.de/zena/zena_playground.zip"}
        end

        should 'return an error about missing content length' do
          file, error = get_attachment
          assert_nil file
          assert_equal 'unknown size: cannot fetch url', error
        end
      end


      context 'that is not valid' do
        setup do
          @invalid_urls = ['lkja a93z/3', 'bad .uri', '.']
        end

        should 'return an error' do
          @invalid_urls.each do |url|
            @params = {'attachment_url' => url}
            file, error = get_attachment
            assert_nil file
            assert_equal 'invalid url', error
          end
        end
      end

      context 'that does not exist' do
        setup do
          @params = {'attachment_url' => "http://example.org/xyz.zip"}
        end

        should 'return an error about missing content length' do
          file, error = get_attachment
          assert_nil file
          assert_equal 'not found', error
        end
      end
    end
  else
    puts "upload by url disabled (no network)"
  end # if has_network?
end
