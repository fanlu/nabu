# coding=utf-8
'''@file character.py
contains the character target normalizer'''

def normalize(transcription, alphabet):
    '''normalize a transcription

    Args:
        transcription: the transcription to be normalized as a string

    Returns:
        the normalized transcription as a string space seperated per
        character'''

    #make the transcription lower case and put it into a list
    normalized = list(transcription.lower().decode("utf-8"))
    #print(alphabet)
    #print(normalized)
    #replace the spaces with <space>
    normalized = [character for character in normalized if character != " "]

    #replace the end of line with <eol>
    #replace the spaces with <space>
    normalized = [character if character != '\n' else '<eol>'
                  for character in normalized]

    #replace unknown characters with <unk>
    normalized = [character.encode("utf-8") if character in alphabet else '<unk>'
                  for character in normalized]

    return ' '.join(normalized)
