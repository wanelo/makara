require 'spec_helper'

describe 'Integration of Makara Adapter to Real World Events' do

  # Test Cases (assuming 3 DBs, Master, slave-a, slave-b)
  # 1) slaves a and b go down; all requests go to master
  # 2) slave a goes down, then comes back; traffic should eventually go back to slave a
  # 3) slave a goes down; while down, all reads to slave b
  # 4) master goes down, slaves are up; writes should cause normal rails exceptions
  # 5) master goes down, all slaves also down; all sql actions should cause normal rails exceptions
  # 6) master goes down, all writes cause errors, then master comes back; app should reconnect to master
  # 7) we can force (or unforce) a process (rake/DJ) to only be on master and ignore the slaves
  # 8) test stickyness of slaves (read from slave A, you shouldn't read from slave B)
  # 9) test stickyness of master (write first, then all reads should stay on master)
  # 10) complex queries (insert into… where select a from b) still go to master
  # 11) oddball queries all go to master (grant ALL to user@host…)
  # 12) i should be able to verify my connection at the beginning of a request

  before { connect!(config) }

  let(:select){ "select * from users" }
  let(:insert){ "insert into users (name) values ('whatever')" }
  let(:complex){ "insert into users (name) select name from people" }
  let(:unknown){ "some random query we dont know about" }

  let(:master){ adapter.mcon }
  let(:slaveA){ adapter.scon(1) }
  let(:slaveB){ adapter.scon(2) }

  context 'with a dry configuration' do

    let(:config){ dry_multi_slave_config  }


    it '(1) should route all requests to the master if both slaves go down' do
      down!(slaveA, slaveB)
      master.should_receive(:execute).with(select, nil).and_call_original

      expect(adapter.execute(select)).to_not be_nil
    end

    it '(2) should give traffic back to a revived slave' do
      slaveA.should_receive(:reconnect!).and_return(true)
      down!(slaveA)

      2.times do
        expect(adapter.execute(select)).to_not be_nil
      end

      later do
        up!(slaveA)
        2.times do
          expect(adapter.execute(select)).to_not be_nil
        end
      end
    end

    it '(3) should pass all read traffic to living slaves' do
      down!(slaveA)
      slaveA.should_receive(:execute).never

      5.times do
        expect(adapter.execute(select)).to_not be_nil
      end
    end

    it '(4) should raise exceptions when master goes down' do
      down!(master)

      lambda{
        adapter.execute(insert)
      }.should raise_error(ActiveRecord::StatementInvalid)
    end

    it '(5) should raise all exceptions if all nodes are down' do
      down!(master, slaveA, slaveB)

      [select, insert].each do |statement|
        lambda{
          adapter.execute(statement)
        }.should raise_error(ActiveRecord::StatementInvalid)
      end
    end

    it '(6) should causes errors when master is down, but if it comes back start working again' do
      down!(master)

      lambda{
        adapter.execute(insert)
      }.should raise_error(ActiveRecord::StatementInvalid)

      later do
        up!(master)
        lambda{
          expect(adapter.execute(insert)).to_not be_nil
        }.should_not raise_error
      end
    end


    it '(7) can be forced to use the master' do
      master.should_receive(:execute).with(select, nil).twice.and_call_original
      master.should_receive(:execute).with(insert, nil).twice.and_call_original

      adapter.force_master!

      2.times do
        expect(adapter.execute(select)).to_not be_nil
      end

      2.times do
        expect(adapter.execute(insert)).to_not be_nil
      end
    end

    it '(7) can unforce the master' do
      down!(slaveA)
      master.should_receive(:execute).with(select, nil).twice.and_call_original
      slaveB.should_receive(:execute).with(select, nil).twice.and_call_original

      adapter.force_master!

      2.times do
        expect(adapter.execute(select)).to_not be_nil
      end

      adapter.unforce_master!

      2.times do
        expect(adapter.execute(select)).to_not be_nil
      end
    end

    it '(12) can call verify without blowing up when one slave node is down' do
      down!(slaveA)

      lambda {
        adapter.verify!
      }.should_not raise_error

      adapter.should_not be_stuck
    end

  end

  context 'with a sticky configuration' do

    let(:config){ multi_slave_config }

    it "(8) should stick to a slave once it's used" do
      slaveA.should_receive(:execute).never
      10.times do
        expect(adapter.execute(select)).to_not be_nil
      end
    end

    it "(9) should stick to the master for all queries once it's used" do
      adapter.execute(insert)
      slaveA.should_receive(:execute).never
      slaveB.should_receive(:execute).never

      master.should_receive(:execute).with(select, nil).exactly(10).times.and_call_original

      10.times do
        expect(adapter.execute(select)).to_not be_nil
      end
    end

    it '(10) should send complex queries including subselects to master' do
      master.should_receive(:execute).with(complex, nil).once.and_call_original
      expect(adapter.execute(complex)).to_not be_nil
    end

    it '(11) send unrecognized queries to master' do
      master.should_receive(:execute).with(unknown, nil).once.and_call_original
      expect {
        adapter.execute(unknown)
      }.to raise_error(ActiveRecord::StatementInvalid, /syntax error/i)
    end

    it '(12) can call verify without blowing up when one slave node is down' do
      down!(slaveA)

      lambda{
        adapter.verify!
      }.should_not raise_error

      adapter.should_not be_stuck
    end

  end

  def later
    Delorean.time_travel_to 70.seconds.from_now do
      yield
    end
  end


  def up!(*cons)
    cons.each do |con|
      con.unstub(:execute)
      con.unstub(:verify!)
    end
  end

  def down!(*cons)
    cons.each do |con|
      con.stub(:execute).and_raise(ActiveRecord::StatementInvalid.new('closed connection'))
      con.stub(:verify!).and_raise(ActiveRecord::StatementInvalid.new('closed connection'))
    end
  end

end
