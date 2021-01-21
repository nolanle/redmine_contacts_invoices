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

module RedmineInvoices
  module Patches
    module ApplicationHelperPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method :format_object_without_invoices, :format_object
          alias_method :format_object, :format_object_with_invoices

          def invoice_templates_check_box_tags(name, templates)
            return '' if templates.blank?
            s = ''
            templates.each do |template|
              s << "<label>#{check_box_tag name, template.id, false, id: nil} #{h template.name}</label>\n"
            end
            s.html_safe
          end
        end
      end

      module InstanceMethods
        def format_object_with_invoices(object, html = true, &block)
            format_object_without_invoices(object, html, &block)
        end
      end
    end
  end
end

unless ApplicationHelper.included_modules.include?(RedmineInvoices::Patches::ApplicationHelperPatch)
  ApplicationHelper.send(:include, RedmineInvoices::Patches::ApplicationHelperPatch)
end
