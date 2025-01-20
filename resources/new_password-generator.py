import random

# gather our characters
lower = 'abcdefghijklmnopqrstuvwxyz'
upper = lower.upper()

symbols = '~!@#$%^&*()_+{}|:"<>?/.,;\][=-`'
numbers = '1234567890'
all = lower + upper + symbols + numbers

#set password length
length = 20

# loop through each characters

password = ''
for _ in range(length):
    password = ''.join([password, random.choice(all)])

print(password)
