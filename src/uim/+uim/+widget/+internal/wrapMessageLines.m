function messageLines = wrapMessageLines(message, maxCharsPerLine)
%wrapMessageLines Split a message into lines at spaces and path separators
%
%   messageLines = uim.widget.internal.wrapMessageLines(message, maxCharsPerLine)
%   returns a column cell array of lines, each at most maxCharsPerLine
%   characters where a break point allows it. Breaks happen after
%   spaces and after file separators, so long paths wrap too. A single
%   token longer than the limit is placed on its own line unbroken.

    arguments
        message {mustBeTextScalar}
        maxCharsPerLine (1,1) double {mustBeInteger, mustBePositive}
    end

    message = char(message);
    messageLines = cell(0, 1);
    if isempty(message)
        return
    end

    % Split into tokens, keeping the separator after each token so it
    % is retained when the tokens are joined again.
    [tokens, separators] = strsplit(message, {filesep, ' '});
    separators{end+1} = '';
    tokens = strcat(tokens, separators);

    % A message ending in a separator leaves an empty last token, which
    % would otherwise become an empty line after a long token.
    tokens = tokens(~cellfun(@isempty, tokens));

    tokenLengths = cellfun(@numel, tokens);
    firstToken = 1;

    while firstToken <= numel(tokens)
        cumulativeLength = cumsum(tokenLengths(firstToken:end));
        tokensThatFit = find(cumulativeLength <= maxCharsPerLine, 1, 'last');

        % A single token longer than the limit gets a line to itself:
        % without this the loop would never consume it.
        if isempty(tokensThatFit); tokensThatFit = 1; end

        lastToken = firstToken - 1 + tokensThatFit;
        messageLines{end+1, 1} = [tokens{firstToken:lastToken}]; %#ok<AGROW>
        firstToken = lastToken + 1;
    end
end
