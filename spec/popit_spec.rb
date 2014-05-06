require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'yaml'

# We don't want to test the PopIt API. We want to check that the wrapper works.
#
# @see https://github.com/mysociety/popit/blob/master/lib/apps/api/api_v1.js
describe PopIt do
  let :unauthenticated do
    PopIt.new :instance_name => 'tttest'
  end

  let :authenticated do
    PopIt.new({
      :instance_name => ENV['INSTANCE_NAME'] || 'tttest',
      :user          => ENV['POPIT_USER'] || 'james@opennorth.ca',
      :password      => ENV['POPIT_PASSWORD'],
    })
  end

  it 'should fail to send a request to a bad instance' do
    api = PopIt.new :instance_name => '47cc67093475061e3d95369d'
    expect { api.persons.get }.to raise_error(PopIt::PageNotFound, '404')
  end

  it 'should fail to send a request to a bad version' do
    api = PopIt.new :instance_name => 'tttest', :version => 'v0'
    expect { api.persons.get }.to raise_error(PopIt::PageNotFound, 'page not found')
  end

  context 'with a PopIt instance' do
    let :person do
      unauthenticated.persons.get(:name => 'Foo', :slug => 'foo')[0]
    end

    let :id do
      person['id']
    end

    it 'should fail to send a request to a bad schema' do
      expect { unauthenticated.foo.get }.to raise_error(PopIt::PageNotFound, "collection 'foo' not found")
    end

    context 'when unauthenticated' do
      it 'should get all items' do
        response = unauthenticated.persons.get
        response.should be_an(Array)
      end

      it 'should get one item by name' do
        response = unauthenticated.persons.get :name => 'Foo'
        response.should be_an(Array)
      end

      it 'should get one item' do
        response = unauthenticated.persons(id).get
        # PopIt adds fields e.g. __v, _internal, contact_details, images, links,
        # other_names, personal_details and adds positions_api_url to meta.
        person.each do |k,v|
          unless k == 'meta'
            response[k].should == v
          end
        end
      end

      it 'should fail to get a non-existent item' do
        expect {unauthenticated.persons('bar').get}.to raise_error(PopIt::PageNotFound, "id 'bar' not found")
      end

      it 'should fail to create an item' do
        expect {unauthenticated.persons.post :name => 'John Doe', :slug => 'john-doe'}.to raise_error(PopIt::NotAuthenticated, 'not authenticated')
      end

      it 'should fail to update an item' do
        expect {unauthenticated.persons(id).put :id => id, :name => 'John Doe', :slug => 'john-doe'}.to raise_error(PopIt::NotAuthenticated, 'not authenticated')
      end

      it 'should fail to delete an item' do
        expect {unauthenticated.persons(id).delete}.to raise_error(PopIt::NotAuthenticated, 'not authenticated')
      end
    end

    context 'when authenticated' do
      it 'should create, update and delete an item' do
        response = authenticated.persons.post :name => 'John Smith', :slug => 'john-smith', :contact_details => [{:type => 'email', :value => 'test@example.com'}]
        id = response['id']
        contact_detail_id = response['contact_details'][0]['id']
        response['name'].should == 'John Smith'

        response = authenticated.persons(id).put :id => id, :name => 'John Doe', :slug => 'john-doe'
        response.should == {
          'id'              => id,
          'name'            => 'John Doe',
          'slug'            => 'john-doe',
          'memberships'     => [],
          'links'           => [],
          'contact_details' => [{
            'id'    => contact_detail_id,
            'type'  => 'email',
            'value' => 'test@example.com',
          }],
          'identifiers'     => [],
          'other_names'     => [],
          'url'             => 'http://tttest.popit.mysociety.org/api/v0.1/persons/' + id,
          'html_url'        => 'http://tttest.popit.mysociety.org/persons/' + id,
        }
        authenticated.persons(id).get['name'].should == 'John Doe'

        response = authenticated.persons(id).delete
        response.should == nil
        expect {authenticated.persons(id).get}.to raise_error(PopIt::PageNotFound, "id '#{id}' not found")
      end
    end
  end
end
