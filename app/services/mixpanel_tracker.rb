class MixpanelTracker

  class <<self
    def instance
      @instance ||= new(ENV['MIXPANEL_TOKEN'])
    end

    def track(action, *args)
      return unless ENV['MIXPANEL_TOKEN'].present?
      instance.send action, *args
    end
  end

  def initialize(token)
    @tracker = Mixpanel::Tracker.new(token) do |type, message|
      AMQPQueue.enqueue(:mixpanel, [type, message])
    end

    @maker = Member.find_by_email 'forex@peatio.com'
  end

  def activate(req, mp_cookie, token)
    return unless mp_cookie
    @tracker.track mp_cookie['distinct_id'], "Activation", {email: token.member.email, token: token.token}, req.ip
    @tracker.alias token.member.email, mp_cookie['distinct_id']
    @tracker.people.set(token.member.email, get_profile(token.member), req.ip)
  end

  def signin(req, mp_cookie, member)
    return unless mp_cookie
    @tracker.track mp_cookie['distinct_id'], "Signin", {email: member.email}, req.ip
    @tracker.alias member.email, mp_cookie['distinct_id']
    @tracker.people.increment(member.email, {'Signin Count' => 1}, req.ip)

    profile = get_profile(member).merge('Last Signin At' => Time.now.to_s(:utc))
    @tracker.people.set(member.email, profile, req.ip)
  end

  def id_document_created(req, mp_cookie, id_document)
    member = id_document.member
    @tracker.people.set(member.email, {'$name' => member.name, 'verified' => true}, req.ip)
  end

  def order_accepted(order)
    id = order.member.email
    @tracker.track id, "Order Accepted", order.to_matching_attributes
    @tracker.people.increment id, "Order Accepted" => 1
  end

  def order_canceled(order)
    id = order.member.email
    @tracker.track id, "Order Canceled", order.to_matching_attributes
    @tracker.people.increment id, "Order Canceled" => 1
  end

  def sms_token_sent(req, mp_cookie, member, token)
    @tracker.track member.email, "SMS Verify Code Sent", {phone: token.phone_number, code: token.token}, req.ip
  end

  def phone_number_verified(req, mp_cookie, member, token)
    @tracker.track member.email, "Phone Number Verified", {phone: token.phone_number, code: token.token}, req.ip
    @tracker.people.set member.email, {'$phone' => token.phone_number}, req.ip
  end

  def valuable_trade(trade)
    return unless @maker
    if trade.ask_member_id != @maker.id && trade.bid_member_id != @maker.id
      @tracker.track @maker.email, "Trade (human to human)", trade.as_json
    elsif trade.ask_member_id != @maker.id || trade.bid_member_id != @maker.id
      @tracker.track @maker.email, "Trade (maker to human)", trade.as_json
    end
  end

  private

  def get_profile(member)
    { '$email'       => member.email,
      '$name'        => member.name,
      '$created'     => member.created_at,
      'sn'           => member.sn,
      '$phone'       => member.phone_number }
  end

end
