#!/usr/bin/env ruby

require 'rubygems'
require 'json'
require 'tmail'
require 'time'
require 'net/http'

USERNAME = "pooptag"
PASSWORD = ENV['PASSWORD']
TRENGINE = ENV['TRENGINE']

# The window of time in which a pooper may be tagged (in seconds)
POOP_WINDOW = 60*30
# The minimum time a pooper must rest between poops (in seconds)
POOP_CYCLE  = 60*60*4

class Request
  def initialize msg
    @sender = msg['X-TwitterSenderScreenName'].body
    @recipient = msg['X-TwitterRecipientScreenName'].body
    @created_at = Time.parse(msg['X-TwitterCreatedAt'].body)
    @type = msg['X-TwitterEmailType'].body
    @text = msg.parts[0].body.split("\n")[0]
  end

  def following?
    @type == 'is_following'
  end

  def respond
    if following?
      follow
    else
      direct random_response
      update "\"#{@text}\" @#{@sender}" unless @text =~ /^\s*\S\s*$/
      check_for_tag
      trengine
    end
  end

  def check_for_tag
    if eligible_to_tag
      tagged = active_poopers
      update "Ding! @#{@sender} just tagged #{tagged}" unless tagged.empty?
    end
  end

  def eligible_to_tag
    # The first message in the list should correspond to *this* one, so ignore it!
    last = recent.select{|x| x['sender']['screen_name'] == @sender}[1]
    not(last) or (@created_at - Time.parse(last['created_at']) > POOP_CYCLE)
  end

  def active_poopers
    poopers = recent.select{|x| @created_at - Time.parse(x['created_at']) < POOP_WINDOW}
    format(poopers.map{|x| x['sender']['screen_name']}.uniq - [@sender])
  end

  def format names 
    names.map! { |x| '@'+x }
    if names.size > 1
      names[0...-1].join(', ') + " and " + names[-1]
    else
      names.first or ""
    end
  end
    
  def recent
    @recent ||= recent_direct_messages
  end

  def follow
    req = Net::HTTP::Post.new("/friendships/create/#{@sender}.xml")
    twitter req
  end

  def direct message
    req = Net::HTTP::Post.new('/direct_messages/new.xml')
    req.set_form_data({'user'=>@sender, 'text'=>message})
    twitter req
  end

  def update message
    req = Net::HTTP::Post.new('/statuses/update.xml')
    req.set_form_data({'status'=>message[0,140], 'source'=>'pooptag'})
    twitter req
  end
  
  def recent_direct_messages
    req = Net::HTTP::Get.new("/direct_messages.json")
    JSON.parse(twitter(req))
  end

  def twitter req
    req.basic_auth USERNAME, PASSWORD
    http('twitter.com', req)
  end

  def trengine
    req = Net::HTTP::Post.new("/#{TRENGINE}")
    req["content-type"] = "application/json"
    req.body = {@sender => 1, 'pooptag' => 1}.to_json
    http('trengine.com', req)
  end

  def http host, req
    res = Net::HTTP.start(host) {|http| http.request(req) }
    unless Net::HTTPSuccess === res
      STDERR.puts res.body
      res.error!
    end
    res.body
  end
  
  def to_s
    "type: #{@type}\nfrom: #{@sender}\n  to: #{@recipient}\n  at: #{@created_at}\nbody: #{@text}"
  end

  def random_response
    # 120 characters of asterisks
    #     ************************************************************************************************************************
    x = [
         "Have a nice poop!",
         "The word 'feces' is the plural of the Latin word 'faex' meaning 'dregs'.",
         "There is no singular form of the word 'feces' in the English language, making it a 'plurale tantum'.",
         "'Night soil' is a euphemism for human feces used as fertilizer, a risky but common practice in developing countries.",
         "One person's annual excrement is the equivalent of 25 kilograms (55 lb) of commercially produced fertilizer.",
         "Ideal stools are of type 3 or 4 on the Bristol Stool Chart: like a soft sausage, either smooth or with small cracks.",
         "Besides poop, other synonyms for feces include crap, turd, dookie, stinky, sea pickle, sewer trout, and ass apple.",
         "Feces may still contain a large amount of energy, often 50% of that of the original food.",
         "Young elephants eat their mother's feces to gain essential gut flora.",
         "Some caterpillars shoot their feces away from themselves in an explosive burst, confusing potential predators.",
         "In humans, defecation may occur from once every 2-3 days to several times a day.",
         "The brown color of poop comes from a combination of bile and bilirubin, which comes from dead red blood cells.",
         "The poop of a breast-fed baby remains soft, pale yellowish, and not-unpleasantly scented.",
         "A green stool is from rapid transit of feces through the intestines.",
         "Black stools caused by blood usually indicate a problem in the intestines.",
         "Red streaks of blood in a stool are usually caused by bleeding in the rectum or anus.",
         "Because of their high fiber content, undigested foods found in feces include seeds, nuts, corn and beans.",
         "Beets may turn feces different hues of red.",
         "Some breakfast cereals can cause unusual feces coloring if eaten in sufficient quantities.",
         "In India, the anus is washed with water using the left hand after pooping.",
         "In Ancient Rome, a communal sponge was used after pooping, which was then rinsed in a bucket of salt water.",
         "Consistency and shape of stools may be classified medically according to the Bristol Stool Chart.",
         "Consumption of spicy foods may result in the spices being undigested and adding to the odor of feces.",
         "Human perception of feces odor is a subjective matter; an animal that eats feces may be attracted to its odor.",
         "Some animal feces, especially those of the camel, bison and cow, is used as fuel when dried out.",
         "In many Western countries, the anus and buttocks are cleansed with toilet paper or similar paper products.",
         "The use of toilet paper for post-defecation cleansing was first started in China.",
         "In modern flush toilets, using newspaper as toilet paper is liable to cause blockages.",
         "in Japan, approximately half of all households have a form of bidet.",
         "Nearly 40 percent of the world's population lacks access to toilets.",
         "The olfactory components of flatulence include skatole, indole, and sulfurous compounds.",
         "The odor in flatulence comes from hydrogen sulphide, which comes from foods in people's diet.",
         "Nerve endings in the rectum usually enable individuals to distinguish between flatus and feces, but not always.",
         "Interest in the causes of flatulence was spurred by the space program.",
         "Rice is the only starch that does not produce intestinal gas when broken down by the large intestine.",
         "There is no known cure for Irritable Bowel Syndrome (IBS).",
         "Peristalsis: the waves of muscular contraction in the colon that move fecal matter through the digestive tract.",
         "The urge to defecate arises from the reflex contraction of rectal muscles and relaxation of the anal sphincter.",
         "If the urge to defecate is ignored, the material in the rectum is returned to the colon by reverse peristalsis.", 
         "When the rectum is full, an increase in intra-rectal pressure forces the walls of the anal canal apart.",
         "Both anal sphincters, along with the puborectalis muscle, pull the anus up over the exiting feces.",
         "Defecation is normally assisted by taking a deep breath and trying to expel this air against a closed glottis.",
         "Be careful! Death has been known to occur in cases where defecation causes an extreme rise in blood pressure.",
         "Be careful! Blackouts can occur by standing up quickly to leave the toilet. Relax.",
         "The natural and instinctive defecation method used by all primates, including humans, is the squatting position.",
         "Squat toilets are used by the vast majority of the world, including most of Africa, Asia and the Middle East.",
         "The widespread use of sit-down toilets in the west is due to the recent advent of indoor plumbing.",
         "The ideal posture for defecation is the squatting position, with the thighs flexed upon the abdomen.",
         "A turd is mostly comprised of water, but the longer it resides within the intestine, the drier it will be.",
         "Birds don't urinate like mammals. Their kidneys excrete waste as uric acid, which turns their poop white.",
         "Cat poop is particularly high in protein. Dogs love it!",
         "To increase the lengths of your turds, try to relax your sphincter as you poop.",
         "Any floaters today? They float because they have high gas content. You may not be farting enough.",
         "The poop of carnivores will smell worse than that of herbivores. Meat protein is rich in sulfides.",
         "Why did Piglet look in the toilet? He was looking for Pooh!",
         "Relax and breath deeply.  Don't rush the inevitable.",
        ]
    x[rand(x.size)]
  end
end

request = Request.new(TMail::Mail.parse(STDIN.read))
request.respond
