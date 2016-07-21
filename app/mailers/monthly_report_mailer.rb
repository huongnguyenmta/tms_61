class MonthlyReportMailer < ApplicationMailer
  default from: Settings.mail_from

  def monthly_report_email user

    mail(to: email, subject: t("mail.subject_monthly_report"))
  end
end
