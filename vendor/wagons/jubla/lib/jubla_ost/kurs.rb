# encoding: utf-8
module JublaOst
  class Kurs < Base
    self.table_name = 'tKurs'
    self.primary_key = 'KUID'

    class << self
      def migrate
        find_each do |legacy|
          if legacy.kbez.present? && legacy.Kanton != 'CH' && JublaOst::Config.event_kind_id(legacy.stufe).present?
            course = Event::Course.new
            course.groups = [Group::State.find(JublaOst::Config.kanton_id(legacy.Kanton))]
            migrate_attributes(course, legacy)
            course.save!
            cache[legacy.KUID] = course.id
            course
          end
        end
      end

      def questions
        @questions ||= {}
      end

      private

      def migrate_attributes(current, legacy)
        current.name = legacy.kbez
        current.location = combine("\n", legacy.adresse, legacy.ort)
        current.maximum_participants = legacy.tnvorgesehen
        current.application_opening_at = legacy.anmeldestart
        current.application_closing_at = legacy.anmeldeschluss
        current.cost = legacy.kosten
        current.number = legacy.knr
        current.motto = legacy.motto
        current.description = legacy.bem
        current.kind_id = JublaOst::Config.event_kind_id(legacy.stufe)
        current.application_contact_id = current.possible_contact_groups.first.id

        migrate_urls(current, legacy)
        migrate_dates(current, legacy)
        migrate_questions(current, legacy)

        current.state = current.dates.first.start_at.year == 2013 ? 'application_open' : 'closed'
      end

      def migrate_urls(current, legacy)
        urls = {urlhomepage: 'Homepage', urlfotos: 'Fotos', urlgb: 'Gästebuch'}
        values = {}
        urls.each do |attr, label|
          val = legacy.send(attr).presence
          values[label] = val if val
        end
        if values.present? && current.description?
          current.description += "\n\n"
        end
        values.each do |label, value|
          current.description += "#{label}: #{value}\n"
        end
      end

      def migrate_dates(current, legacy)
        create_date(current,
                    combine(" ", 'Vorweekend', legacy.vwort),
                    legacy.vwstart,
                    legacy.vwende)

        create_date(current, 'Kurs', legacy.start, legacy.ende)
      end

      def create_date(current, label, start, finish)
        if start.present?
          date = current.dates.build
          date.label = label
          date.start_at = start
          date.finish_at = finish
        end
      end

      def migrate_questions(current, legacy)
        cache = questions[legacy.KUID] ||= {}

        cache[:abo] = build_question(current, 'Ich habe folgendes ÖV Abo', 'GA, Halbtax / unter 16, keine Vergünstigung')
        cache[:vegi] = build_question(current, 'Ich bin Vegetarier', 'ja, nein')
      end

      def build_question(current, question, choices)
        q = current.questions.build
        q.question = question
        q.choices = choices
        q
      end

    end
  end
end