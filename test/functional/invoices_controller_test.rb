# encoding: utf-8
#
# This file is a part of Redmine Invoices (redmine_contacts_invoices) plugin,
# invoicing plugin for Redmine
#
# Copyright (C) 2011-2020 RedmineUP
# https://www.redmineup.com/
#
# redmine_contacts_invoices is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# redmine_contacts_invoices is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with redmine_contacts_invoices.  If not, see <http://www.gnu.org/licenses/>.

require File.expand_path('../../test_helper', __FILE__)

class InvoicesControllerTest < ActionController::TestCase
  include RedmineContacts::TestHelper
  include RedmineInvoices::TestHelper

  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :issues,
           :issue_statuses,
           :versions,
           :trackers,
           :projects_trackers,
           :issue_categories,
           :enabled_modules,
           :enumerations,
           :attachments,
           :workflows,
           :custom_fields,
           :custom_values,
           :custom_fields_projects,
           :custom_fields_trackers,
           :time_entries,
           :journals,
           :journal_details,
           :queries

  RedmineInvoices::TestCase.create_fixtures(Redmine::Plugin.find(:redmine_contacts).directory + '/test/fixtures/', [:contacts,
                                                                                                                    :contacts_projects,
                                                                                                                    :deals,
                                                                                                                    :notes,
                                                                                                                    :tags,
                                                                                                                    :taggings])

  RedmineInvoices::TestCase.create_fixtures(Redmine::Plugin.find(:redmine_contacts_invoices).directory + '/test/fixtures/', [:invoices,
                                                                                                                             :invoice_lines])

  # TODO: Test for delete tags in update action

  def setup
    RedmineInvoices::TestCase.prepare
    User.current = nil
  end

  test 'should get index' do
    # log_user('admin', 'admin')
    @request.session[:user_id] = 1
    Setting.default_language = 'en'

    compatible_request :get, :index
    assert_response :success
    assert_not_nil invoices_in_list
  end

  def should_get_json
    Setting.rest_api_enabled = '1'
    @user = User.where(:login => 'admin').firs
    @request.env['HTTP_AUTHORIZATION'] = credentials('admin')

    compatible_request :get, :index, :format => 'json', :status_id => '*'
    assert_response :success
    assert_not_nil invoices_in_list
    parsed_response = JSON.parse(@response.body)
    assert_equal parsed_response['invoices'].count, 6
  ensure
    Setting.rest_api_enabled = '0'
  end

  def should_get_json_with_filter
    @user = User.where(:login => 'admin').first
    @request.env['HTTP_AUTHORIZATION'] = credentials('admin')

    compatible_request :get, :index, :format => 'json', :status_id => '3'
    assert_response :success
    assert_not_nil invoices_in_list
    parsed_response = JSON.parse(@response.body)
    assert_equal parsed_response['invoices'].count, 1
  ensure
    Setting.rest_api_enabled = '0'
  end

  def test_get_index_with_sorting
    @request.session[:user_id] = 1
    RedmineInvoices.settings['invoices_excerpt_invoice_list'] = 1
    compatible_request :get, :index, :sort => 'invoices.number:desc'
    assert_response :success
  end

  test 'should get index in project' do
    # log_user('admin', 'admin')
    @request.session[:user_id] = 1
    Setting.default_language = 'en'

    compatible_request :get, :index, :project_id => 1
    assert_response :success
    assert_not_nil invoices_in_list
  end

  test 'should get index deny user in project' do
    @request.session[:user_id] = 4
    compatible_request :get, :index, :project_id => 1
    assert_response :forbidden
  end

  test 'should get index with empty settings' do
    # log_user('admin', 'admin')
    @request.session[:user_id] = 1
    Setting.default_language = 'en'
    with_invoice_settings({}) do
      compatible_request :get, :index
      assert_response :success
    end
  end

  def test_index_with_short_filters
    @request.session[:user_id] = 1
    to_test = {
      'status_id' => {
        'o' => { :op => 'o', :values => [''] },
        'c' => { :op => 'c', :values => [''] },
        '1' => { :op => '=', :values => ['1'] },
        '1|3|2' => { :op => '=', :values => ['1', '3', '2'] },
        '=1' => { :op => '=', :values => ['1'] },
        '!3' => { :op => '!', :values => ['3'] },
        '!1|3|2' => { :op => '!', :values => ['1', '3', '2'] } },
      'invoice_date' => {
        '2011-10-12' => { :op => '=', :values => ['2011-10-12'] },
        '=2011-10-12' => { :op => '=', :values => ['2011-10-12'] },
        '>=2011-10-12' => { :op => '>=', :values => ['2011-10-12'] },
        '<=2011-10-12' => { :op => '<=', :values => ['2011-10-12'] },
        '><2011-10-01|2011-10-30' => { :op => '><', :values => ['2011-10-01', '2011-10-30'] },
        '<t+2' => { :op => '<t+', :values => ['2'] },
        '>t+2' => { :op => '>t+', :values => ['2'] },
        't+2' => { :op => 't+', :values => ['2'] },
        't' => { :op => 't', :values => [''] },
        'w' => { :op => 'w', :values => [''] },
        '>t-2' => { :op => '>t-', :values => ['2'] },
        '<t-2' => { :op => '<t-', :values => ['2'] },
        't-2' => { :op => 't-', :values => ['2'] } },
      'number' => {
        'INV' => { :op => '=', :values => ['INV'] },
        '~IN' => { :op => '~', :values => ['IN'] },
        '!~IN' => { :op => '!~', :values => ['IN'] } },
      'created_at' => {
        '>=2011-10-12' => { :op => '>=', :values => ['2011-10-12'] },
        '<t-2' => { :op => '<t-', :values => ['2'] },
        '>t-2' => { :op => '>t-', :values => ['2'] },
        't-2' => { :op => 't-', :values => ['2'] } },
      'updated_at' => {
        '>=2011-10-12' => { :op => '>=', :values => ['2011-10-12'] },
        '<t-2' => { :op => '<t-', :values => ['2'] },
        '>t-2' => { :op => '>t-', :values => ['2'] },
        't-2' => { :op => 't-', :values => ['2'] } },
      'amount' => {
        '=13.4' => { :op => '=', :values => ['13.4'] },
        '>=45' => { :op => '>=', :values => ['45'] },
        '<=125' => { :op => '<=', :values => ['125'] },
        '><10.5|20.5' => { :op => '><', :values => ['10.5', '20.5'] },
        '!*' => { :op => '!*', :values => [''] },
        '*' => { :op => '*', :values => [''] } }
    }

    default_filter = { 'status_id' => { :operator => 'o', :values => [''] } }

    to_test.each do |field, expression_and_expected|
      expression_and_expected.each do |filter_expression, expected|
        compatible_request :get, :index, :set_filter => 1, field => filter_expression

        assert_response :success
        assert_not_nil invoices_in_list
      end
    end
  end

  def test_index_with_query_grouped
    ['contact', 'assigned_to', 'status', 'currency',
     'language', 'project', 'order_number', 'contact_country', 'contact_city'].each do |by|
      @request.session[:user_id] = 1
      compatible_request :get, :index, :set_filter => 1, :group_by => by, :sort => 'status:desc'
      assert_response :success
    end
  end

  test 'should get index with sorting' do
    @request.session[:user_id] = 1
    compatible_request :get, :index, :sort => 'amount'
    assert_response :success
  end

  test 'should get index with grouping' do
    @request.session[:user_id] = 1
    compatible_request :get, :index, :group_by => 'assigned_to'
    assert_response :success
    assert_select 'div#contact_list tr.group'
  end

  test 'should get show' do
    # RedmineInvoices.settings[:total_including_tax] = true
    # log_user('admin', 'admin')
    @request.session[:user_id] = 1
    Setting.default_language = 'en'

    invoice = Invoice.find(1)
    invoice.save

    compatible_request :get, :show, :id => 1
    assert_response :success

    assert_select 'div.subject h3', "Domoway - $3,265.65"
    assert_select 'div.invoice-lines table.list tr.line-data td.description', "Consulting work"
  end

  def test_show_unassigned
    # RedmineInvoices.settings[:total_including_tax] = true
    # log_user('admin', 'admin')
    @request.session[:user_id] = 1
    Setting.default_language = 'en'

    invoice = Invoice.find(1)
    invoice.update_attribute(:assigned_to_id, nil)
    invoice.update_attribute(:template_id, nil)
    compatible_request :get, :show, :id => 1
    assert_response :success
    assert_select 'h2', "Invoice ##{invoice.number}"
  end

  def test_put_update_with_empty_discount
    @request.session[:user_id] = 1
    compatible_request :put, :update, :id => 1, :invoice => { :discount => '' }
    assert_equal 0, Invoice.find(1).discount
  end

  def test_get_show_as_pdf
    @request.session[:user_id] = 1
    Setting.default_language = 'en'

    compatible_request :get, :show, :id => 1, :format => 'pdf'
    assert_response :success
    assert_equal 'application/pdf', @response.content_type
  end

  def test_should_get_show_as_pdf_without_client
    @request.session[:user_id] = 1
    Setting.default_language = 'en'
    invoice = Invoice.where(:id => 1).first
    invoice.update_attributes(:contact_id => nil)
    compatible_request :get, :show, :id => 1, :format => 'pdf'
    assert_response :success
    assert_equal 'application/pdf', @response.content_type
  end

  test 'should get new' do
    @request.session[:user_id] = 2
    compatible_request :get, :new, :project_id => 1
    assert_response :success
    assert_select 'input#invoice_number'
    assert_select 'textarea#invoice_lines_attributes_0_description'
  end

  test 'should not get new by deny user' do
    @request.session[:user_id] = 4
    compatible_request :get, :new, :project_id => 1
    assert_response :forbidden
  end

  test 'should post create' do
    @request.session[:user_id] = 1
    assert_difference 'Invoice.count' do
      compatible_request :post, :create, 'invoice' => { 'number' => '1/005',
                                                        'discount' => '10.1',
                                                        'lines_attributes' => { '0' => { 'tax' => '10.2',
                                                                                         'price' => '140.0',
                                                                                         'quantity' => '23.0',
                                                                                         'units' => 'products',
                                                                                         '_destroy' => '',
                                                                                         'description' => 'Line one' } },
                                                        'discount_type' => '0',
                                                        'contact_id' => '1',
                                                        'invoice_date' => '2011-12-01',
                                                        'due_date' => '2011-12-03',
                                                        'description' => 'Test description',
                                                        'currency' => 'GBR',
                                                        'status_id' => '1' },
                                         'project_id' => 'ecookbook'
    end
    assert_redirected_to :controller => 'invoices', :action => 'show', :id => Invoice.last.id

    invoice = Invoice.where(:number => '1/005').first
    assert_not_nil invoice
    assert_equal 10.1, invoice.discount
    assert_equal 'Line one', invoice.lines.first.description
    assert_equal 10.2, invoice.lines.first.tax
    assert_equal 23.0, invoice.lines.first.quantity
    assert_equal 'products', invoice.lines.first.units
  end

  test 'should not post create by deny user' do
    @request.session[:user_id] = 4
    compatible_request :post, :create, :project_id => 1, 'invoice' => { 'number'=>'1/005' }
    assert_response :forbidden
  end

  test 'should get edit' do
    @request.session[:user_id] = 1
    compatible_request :get, :edit, :id => 1
    assert_response :success
    assert_select 'h2', 'Edit invoice'
    assert_select 'textarea#invoice_lines_attributes_0_description', 'Consulting work'
  end

  test 'should put update' do
    @request.session[:user_id] = 1

    invoice = Invoice.find(1)
    new_number = '2/001'

    compatible_request :put, :update, :id => 1, :invoice => { :number => new_number }
    assert_redirected_to :action => 'show', :id => '1'
    invoice.reload
    assert_equal new_number, invoice.number
  end

  test 'should post destroy' do
    @request.session[:user_id] = 1
    compatible_request :delete, :destroy, :id => 1
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert_nil Invoice.where(:id => 1).first
  end

  test 'should bulk_destroy' do
    @request.session[:user_id] = 1
    assert_not_nil Invoice.where(:id => 1).first
    compatible_request :delete, :bulk_destroy, :ids => [1], :project_id => 'ecookbook'
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert_nil Invoice.where(:id => 1).first
  end

  test 'should bulk_update' do
    @request.session[:user_id] = 1
    compatible_request :put, :bulk_update, :ids => [1, 2], :invoice => { :status_id => 2 }
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert(Invoice.find([1, 2]).all? { |e| e.status_id == 2 })
  end

  test 'should get context menu' do
    @request.session[:user_id] = 1
    compatible_xhr_request :get, :context_menu, :back_url => '/projects/ecookbok/invoices', :project_id => 'ecookbook', :ids => ['1', '2']
    assert_response :success
  end

  class InvoicesPermissionTest < ActionController::TestCase
    fixtures :projects, :users, :roles, :members, :member_roles

    def setup
      @project = Project.find(1)
      @user = User.find(2)
      @request.session[:user_id] = @user.id
      @project.enable_module! :contacts_invoices
      @controller = InvoicesController.new
    end

    def test_that_user_with_add_invoices_can_get_new
      @user.roles_for_project(@project).first.add_permission! :add_invoices
      compatible_request :get, :new, :project_id => @project.id
      assert_response :success
    end

    def test_that_edit_invoices_allows_to_get_new
      @user.roles_for_project(@project).first.add_permission! :edit_invoices
      compatible_request :get, :new, :project_id => @project.id
      assert_response :success
    end

    def test_that_edit_own_invoices_also_allows_to_get_new
      @user.roles_for_project(@project).first.add_permission! :edit_own_invoices
      compatible_request :get, :new, :project_id => @project.id
      assert_response :success
    end

    def test_that_user_with_add_invoices_can_post_on_create
      @user.roles_for_project(@project).first.add_permission! :add_invoices
      assert_difference 'Invoice.count' do
        compatible_request :post, :create, :project_id => @project.id,
                                           :invoice => {
                                             :number => '1/123',
                                             :status_id => 3,
                                             :invoice_date => '2018-02-16'
                                           }
      end
      assert_redirected_to invoice_url(Invoice.last)
    end

    def test_that_edit_invoices_allows_post_on_create
      @user.roles_for_project(@project).first.add_permission! :edit_invoices
      assert_difference 'Invoice.count' do
        compatible_request :post, :create, :project_id => @project.id,
                                           :invoice => {
                                             :number => '1/123',
                                             :status_id => 3,
                                             :invoice_date => '2018-02-16'
                                           }
      end
      assert_redirected_to invoice_url(Invoice.last)
    end

    def test_that_edit_own_invoices_also_allows_to_post_on_create
      @user.roles_for_project(@project).first.add_permission! :edit_own_invoices
      assert_difference 'Invoice.count' do
        compatible_request :post, :create, :project_id => @project.id,
                                           :invoice => {
                                             :number => '1/123',
                                             :status_id => 3,
                                             :invoice_date => '2018-02-16'
                                           }
      end
      assert_redirected_to invoice_url(Invoice.last)
    end

    def test_autocomplete_returns_multiproject_data
      EnabledModule.create(project_id: 2, name: 'contacts_invoices')

      @request.session[:user_id] = 1
      compatible_request :get, :auto_complete, :project_id => @project.id
      assert_response :success
      assert_equal [1,2,3,4,5,6], JSON.parse(response.body).map { |inv| inv['value'] }.sort
    end
  end
end
