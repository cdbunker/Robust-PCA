clear all

N = 44;
start = 1;
I=imread(strcat(strcat('frame_', num2str(start)),'.jpg'));
height = size(I,2);
width = size(I,1);
D=height*width;
X = zeros(D,N);

for it=start:start+N-1
    I=imread(strcat(strcat('frame_', num2str(it)),'.jpg'));
    %I=single(rgb2gray(I));
    X(:,it) = reshape(I,1,[]);
end

XMean = mean(X,2);
Xc=X-XMean;

[U,S,V] = svd(Xc, 0);

XcMag = sum(sum(Xc.^2));

for i=1:N
    s=zeros(size(S));
    s(1:i,1:i) = S(1:i,1:i);
    xc=U*s*V';
    xcMag = sum(sum(xc.^2));
    if (xcMag/XcMag > 0.55)
      break; 
   end
end

d=i;

Uk = U(:,1:d);
C = Uk\Xc;
betaM=3.5;
eps0 = Xc - Uk*(Uk'*Xc);
diffTotal = eps0(:)-median(abs(eps0(:)));
sigma_min = betaM*median(abs(diffTotal(:)));
sigma_temp = zeros(size(I));
beta=2.5;

eps3d = zeros([height,width,N]);
eps3d_MAD = zeros([height,width,N]);

for i=1:N
    eps3d(:,:,i) = reshape(eps0(:,i), [height,width]);
    eps3d_MAD(:,:,i) = medfilt2(abs(eps3d(:,:,i)));
end

for i = 1:height
    for j = 1:width
        pixel_MAD(i,j) = median(abs(eps3d_MAD(i,j,:)));
    end
end

diff = abs(eps3d-pixel_MAD);

for i = 1:height
    for j = 1:width
        diff_med(i,j) = median(abs(diff(i,j)));
    end
end

diff_med(:,1)=0;
diff_med(:,end)=0;
diff_med(1,:)=0;
diff_med(end,:)=0;
final = beta*1.4826*diff_med(:);

sigma_p = max(final, sigma_min);
sigma_max=3*sigma_p;

Bit = Uk;
Cit = C;
mu_p = XMean;
one = ones(N,1);
iterations=120;

for it=1:iterations
    it
    Bit_prev=Bit;
    sigma_p_rep=repmat(sigma_max,1,N);
    
    e_tilda=X-(mu_p+Bit*Cit);
    psi=e_tilda.*sigma_p_rep.^2./((sigma_p_rep.^2+e_tilda.^2).^2);
    mu_p=mu_p + (psi*one)./(N*1./sigma_p.^2);
    e_tilda=X-(mu_p+Bit*Cit);
    psi=e_tilda.*sigma_p_rep.^2./((sigma_p_rep.^2+e_tilda.^2).^2);
    Bit=Bit+(psi*Cit')./((1./sigma_p_rep.^2)*(Cit.*Cit)');
    e_tilda=X-(mu_p+Bit*Cit);
    psi=e_tilda.*sigma_p_rep.^2./((sigma_p_rep.^2+e_tilda.^2).^2);
    Cit=Cit+(Bit'*psi)./((Bit.*Bit)'*(1./sigma_p_rep.^2));
    
    if (it < iterations)
        sigma_p=sigma_p*0.92;
        sigma_p = max(sigma_p,sigma_max);
    end

    if (subspace(Bit,Bit_prev) < 0.0001)
        break
    end
    sigma_p_rep=repmat(sigma_max,1,N);
end

e_tilda=X-(mu_p+Bit*Cit);
mask = abs(e_tilda) < sigma_p_rep/sqrt(3);
W = (sigma_p_rep.^2./((sigma_p_rep.^2+e_tilda.^2).^2));
W_star = W .* mask;

mu_p2=mu_p;
Bit2=Bit;
Cit2=Cit;

p1=randperm(d);
p2=randperm(d);

Bit2=[Bit2, Bit2(:,p1)/10, Bit2(:,fliplr(p1))/10];
Cit2=[Cit2; Cit2(p2,:)/10; Cit2(fliplr(p2),:)/10];

for it=1:30
    it
    mu_p2= sum((W_star.*(X-Bit2*Cit2)),2)./sum(W_star,2);
    for i=1:size(X,2)
        Cit2(:,i)=(Bit2'*(W_star(:,i)*ones(1,size(Bit2,2)).*Bit2))\(W_star(:,i)*ones(1,size(Bit2,2)).*Bit2)'*(X(:,i)-mu_p2);
    end
    for i=1:size(Bit2,1)
        Bit2(i,:)=((Cit2*(Cit2.*(ones(size(Cit2,1),1)*W_star(i,:)))')\(Cit2.*(ones(size(Cit2,1),1)*W_star(i,:)))*(X(i,:)-mu_p2(i))')';
    end
end

e_tilda=X-(mu_p2+Bit2*Cit2);
b=(mu_p2+Bit2*Cit2);

im=44;

figure
imshow(reshape(X(:,im),[width,height]),[]);

figure
foreground=reshape(e_tilda(:,im),[width,height]);
imshow(foreground,[])

figure
background=reshape(b(:,im),[width,height]);
imshow(background,[])

figure
new_img = imbinarize(abs(foreground),10);
large=bwareaopen(new_img,10);
closed=bwmorph(large,'close');
imshow(closed)
