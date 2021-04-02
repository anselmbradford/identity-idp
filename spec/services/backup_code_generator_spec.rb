require 'rails_helper'

RSpec.describe describe BackupCodeGenerator do
  let(:user) { create(:user) }

  subject(:generator) { BackupCodeGenerator.new(user) }

  it 'should generate backup codes ans be able to verify them' do
    codes = generator.create

    codes.each do |code|
      expect(generator.verify(code)).to eq(true)
    end
  end

  it 'should reject invalid codes' do
    generator.generate

    success = generator.verify 'This is a string which will never result from code generation'
    expect(success).to be_falsy
  end

  it 'creates codes with the same salt for that batch' do
    generator.create

    salts = user.backup_code_configurations.map(&:code_salt).uniq
    expect(salts.size).to eq(1)
    expect(salts.first).to_not be_empty

    costs = user.backup_code_configurations.map(&:code_cost).uniq
    expect(costs.size).to eq(1)
    expect(costs.first).to_not be_empty
  end

  it 'creates different salts for different batches' do
    user1 = create(:user)
    user2 = create(:user)

    [user1, user2].each { |user| BackupCodeGenerator.new(user).create }

    user1_salt = user1.backup_code_configurations.map(&:code_salt).uniq.first
    user2_salt = user2.backup_code_configurations.map(&:code_salt).uniq.first

    expect(user1_salt).to_not eq(user2_salt)
  end
end
